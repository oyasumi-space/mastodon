# frozen_string_literal: true

class PostStatusService < BaseService
  include Redisable
  include LanguagesHelper
  include DtlHelper
  include NgRuleHelper

  MIN_SCHEDULE_OFFSET = 5.minutes.freeze

  class UnexpectedMentionsError < StandardError
    attr_reader :accounts

    def initialize(message, accounts)
      super(message)
      @accounts = accounts
    end
  end

  # Post a text status update, fetch and notify remote users mentioned
  # @param [Account] account Account from which to post
  # @param [Hash] options
  # @option [String] :text Message
  # @option [Status] :thread Optional status to reply to
  # @option [Boolean] :sensitive
  # @option [String] :visibility
  # @option [Boolean] :force_visibility
  # @option [String] :searchability
  # @option [String] :spoiler_text
  # @option [Boolean] :markdown
  # @option [String] :language
  # @option [String] :scheduled_at
  # @option [Hash] :poll Optional poll to attach
  # @option [Enumerable] :media_ids Optional array of media IDs to attach
  # @option [Doorkeeper::Application] :application
  # @option [String] :idempotency Optional idempotency key
  # @option [Boolean] :with_rate_limit
  # @option [Enumerable] :allowed_mentions Optional array of expected mentioned account IDs, raises `UnexpectedMentionsError` if unexpected accounts end up in mentions
  # @option [Enumerable] :status_reference_ids Optional array
  # @return [Status]
  def call(account, options = {})
    @account     = account
    @options     = options
    @text        = @options[:text] || ''
    @in_reply_to = @options[:thread]

    return idempotency_duplicate if idempotency_given? && idempotency_duplicate?

    validate_status!
    validate_media!
    preprocess_attributes!

    if scheduled?
      schedule_status!
    else
      process_status!
    end

    redis.setex(idempotency_key, 3_600, @status.id) if idempotency_given?

    unless scheduled?
      postprocess_status!
      bump_potential_friendship!
    end

    @status
  end

  private

  def preprocess_attributes!
    @sensitive    = (@options[:sensitive].nil? ? @account.user&.setting_default_sensitive : @options[:sensitive]) || @options[:spoiler_text].present?
    @text         = @options.delete(:spoiler_text) if @text.blank? && @options[:spoiler_text].present?
    @visibility   = visibility
    @limited_scope = @options[:visibility]&.to_sym if @visibility == :limited && @options[:visibility] != 'limited'
    @searchability = searchability
    @searchability = :private if @account.silenced? && %i(public public_unlisted).include?(@searchability&.to_sym)
    @markdown     = @options[:markdown] || false
    @scheduled_at = @options[:scheduled_at]&.to_datetime
    @scheduled_at = nil if scheduled_in_the_past?
    @reference_ids = (@options[:status_reference_ids] || []).map(&:to_i).filter(&:positive?)
    raise ArgumentError if !Setting.enable_public_unlisted_visibility && (@visibility == :public_unlisted || @searchability == :public_unlisted)
    raise ArgumentError if @account.user&.setting_disabled_visibilities&.include?((@limited_scope || @visibility).to_s)

    if @in_reply_to.present? && ((@options[:visibility] == 'limited' && @options[:circle_id].nil?) || @limited_scope == :reply)
      @visibility = :limited
      @limited_scope = :reply
    end

    load_circle
    overwrite_dtl_post
    process_sensitive_words
  rescue ArgumentError
    raise ActiveRecord::RecordInvalid
  end

  def visibility
    v = @options[:visibility]&.to_sym || @account.user&.setting_default_privacy&.to_sym
    v = :limited if %w(mutual circle reply).include?(@options[:visibility])
    v = :unlisted if %i(public public_unlisted login).include?(v) && @account.silenced?
    v = :public_unlisted if v == :public && !@options[:force_visibility] && !@options[:application]&.superapp && @account.user&.setting_public_post_to_unlisted && Setting.enable_public_unlisted_visibility
    v = Setting.enable_public_unlisted_visibility ? :public_unlisted : :unlisted if !Setting.enable_public_visibility && v == :public
    v
  end

  def load_circle
    return if @visibility == :limited && @limited_scope == :reply && @in_reply_to.present?
    return unless %w(circle limited reply).include?(@options[:visibility])
    raise ArgumentError if @options[:circle_id].nil?

    @circle = @options[:circle_id].present? && Circle.find(@options[:circle_id])
    @limited_scope = :circle
    raise ArgumentError if @circle.nil? || @circle.account_id != @account.id
  end

  def overwrite_dtl_post
    return unless dtl_enabled?

    raw_tags = Extractor.extract_hashtags(@text)
    return if raw_tags.exclude?(dtl_tag_name)
    return unless %i(public public_unlisted unlisted).include?(@visibility)

    @visibility = @account.user&.setting_dtl_force_visibility if %i(public public_unlisted unlisted).include?(@account.user&.setting_dtl_force_visibility)
    @searchability = @account.user&.setting_dtl_force_searchability if %i(public public_unlisted).include?(@account.user&.setting_dtl_force_searchability)
    @dtl = true
  end

  def process_sensitive_words
    if [:public, :public_unlisted, :login].include?(@visibility&.to_sym) && Admin::SensitiveWord.sensitive?(@text, @options[:spoiler_text] || '')
      @text = Admin::SensitiveWord.modified_text(@text, @options[:spoiler_text])
      @options[:spoiler_text] = Admin::SensitiveWord.alternative_text
      @sensitive = true
    end
  end

  def searchability
    return :private if %i(public public_unlisted).include?(@options[:searchability]&.to_sym) && @visibility&.to_sym == :unlisted && @account.user&.setting_disallow_unlisted_public_searchability

    case @options[:searchability]&.to_sym
    when :public
      case @visibility&.to_sym when :public, :public_unlisted, :login, :unlisted then :public when :private then :private else :direct end
    when :public_unlisted
      case @visibility&.to_sym when :public, :public_unlisted, :login, :unlisted then :public_unlisted when :private then :private else :direct end
    when :private
      case @visibility&.to_sym when :public, :public_unlisted, :login, :unlisted, :private then :private else :direct end
    when :direct
      :direct
    when nil
      @account.user&.setting_default_searchability || @account.searchability
    else
      :limited
    end
  end

  def process_status!
    @status = @account.statuses.new(status_attributes)
    process_mentions_service.call(@status, limited_type: @status.limited_visibility? ? @limited_scope : '', circle: @circle, save_records: false)
    safeguard_mentions!(@status)
    validate_status_ng_rules!
    validate_status_mentions!

    @status.limited_scope = :personal if @status.limited_visibility? && !@status.reply_limited? && !process_mentions_service.mentions?

    UpdateStatusExpirationService.new.call(@status)

    # The following transaction block is needed to wrap the UPDATEs to
    # the media attachments when the status is created
    ApplicationRecord.transaction do
      @status.save!
      @status.capability_tokens.create! if @status.limited_visibility?
    end
  end

  def safeguard_mentions!(status)
    return if @options[:allowed_mentions].nil?

    expected_account_ids = @options[:allowed_mentions].map(&:to_i)

    unexpected_accounts = status.mentions.map(&:account).to_a.reject { |mentioned_account| expected_account_ids.include?(mentioned_account.id) }
    return if unexpected_accounts.empty?

    raise UnexpectedMentionsError.new('Post would be sent to unexpected accounts', unexpected_accounts)
  end

  def schedule_status!
    status_for_validation = @account.statuses.build(status_attributes)

    if status_for_validation.valid?
      # Marking the status as destroyed is necessary to prevent the status from being
      # persisted when the associated media attachments get updated when creating the
      # scheduled status.
      status_for_validation.destroy

      # The following transaction block is needed to wrap the UPDATEs to
      # the media attachments when the scheduled status is created

      ApplicationRecord.transaction do
        @status = @account.scheduled_statuses.create!(scheduled_status_attributes)
      end
    else
      raise ActiveRecord::RecordInvalid
    end
  end

  def postprocess_status!
    @account.user.update!(settings_attributes: { default_privacy: @options[:visibility] }) if @account.user&.setting_stay_privacy && !@status.reply? && %i(public public_unlisted login unlisted
                                                                                                                                                           private).include?(@status.visibility.to_sym) && @status.visibility.to_s != @account.user&.setting_default_privacy && !@dtl

    process_hashtags_service.call(@status)
    Trends.tags.register(@status)
    ProcessConversationService.new.call(@status) if @status.limited_visibility? && @status.reply_limited?
    ProcessReferencesService.call_service(@status, @reference_ids, [])
    LinkCrawlWorker.perform_async(@status.id)
    DistributionWorker.perform_async(@status.id)
    ActivityPub::DistributionWorker.perform_async(@status.id) unless @status.personal_limited?
    PollExpirationNotifyWorker.perform_at(@status.poll.expires_at, @status.poll.id) if @status.poll
  end

  def validate_status!
    raise Mastodon::ValidationError, I18n.t('statuses.contains_ng_words') if Admin::NgWord.reject?("#{@options[:spoiler_text]}\n#{@options[:text]}")
    raise Mastodon::ValidationError, I18n.t('statuses.too_many_hashtags') if Admin::NgWord.hashtag_reject_with_extractor?(@text)
  end

  def validate_status_mentions!
    raise Mastodon::ValidationError, I18n.t('statuses.too_many_mentions') if Admin::NgWord.mention_reject_with_extractor?(@text)
    raise Mastodon::ValidationError, I18n.t('statuses.too_many_mentions') if (mention_to_stranger? || reference_to_stranger?) && Admin::NgWord.stranger_mention_reject_with_extractor?(@text)
    raise Mastodon::ValidationError, I18n.t('statuses.contains_ng_words') if (mention_to_stranger? || reference_to_stranger?) && Setting.stranger_mention_from_local_ng && Admin::NgWord.stranger_mention_reject?("#{@options[:spoiler_text]}\n#{@options[:text]}")
  end

  def validate_status_ng_rules!
    result = check_invalid_status_for_ng_rule! @account,
                                               reaction_type: 'create',
                                               spoiler_text: @options[:spoiler_text] || '',
                                               text: @text,
                                               tag_names: Extractor.extract_hashtags(@text) || [],
                                               visibility: @visibility.to_s,
                                               searchability: @searchability.to_s,
                                               sensitive: @sensitive,
                                               media_count: (@media || []).size,
                                               poll_count: @options.dig(:poll, 'options')&.size || 0,
                                               quote: quote_url,
                                               reply: @in_reply_to.present?,
                                               mention_count: mention_count,
                                               reference_count: reference_urls.size,
                                               mention_to_following: !(mention_to_stranger? || reference_to_stranger?)

    raise Mastodon::ValidationError, I18n.t('statuses.violate_rules') unless result
  end

  def mention_count
    @text.gsub(Account::MENTION_RE)&.count || 0
  end

  def mention_to_stranger?
    return @mention_to_stranger if defined?(@mention_to_stranger)

    @mention_to_stranger = @status.mentions.map(&:account).to_a.any? { |mentioned_account| !mentioned_account.following_or_self?(@account) } ||
                           (@in_reply_to && !@in_reply_to.account.following_or_self?(@account))
  end

  def reference_to_stranger?
    referred_statuses.any? { |status| !status.account.following_or_self?(@account) }
  end

  def referred_statuses
    statuses = reference_urls.filter_map { |uri| ActivityPub::TagManager.instance.local_uri?(uri) && ActivityPub::TagManager.instance.uri_to_resource(uri, Status, url: true) }
    statuses += Status.where(id: @reference_ids) if @reference_ids.present?

    statuses
  end

  def quote_url
    ProcessReferencesService.extract_quote(@text)
  end

  def reference_urls
    @reference_urls ||= ProcessReferencesService.extract_uris(@text) || []
  end

  def validate_media!
    if @options[:media_ids].blank? || !@options[:media_ids].is_a?(Enumerable)
      @media = []
      return
    end

    media_max = @options[:poll] ? Status::MEDIA_ATTACHMENTS_LIMIT_WITH_POLL : Status::MEDIA_ATTACHMENTS_LIMIT

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.too_many') if @options[:media_ids].size > media_max

    @media = @account.media_attachments.where(status_id: nil).where(id: @options[:media_ids].take(media_max).map(&:to_i))

    not_found_ids = @options[:media_ids].map(&:to_i) - @media.map(&:id)
    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.not_found', ids: not_found_ids.join(', ')) if not_found_ids.any?

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.images_and_video') if @media.size > 1 && @media.find(&:audio_or_video?)
    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.not_ready') if @media.any?(&:not_processed?)
  end

  def process_mentions_service
    @process_mentions_service ||= ProcessMentionsService.new
  end

  def process_hashtags_service
    ProcessHashtagsService.new
  end

  def scheduled?
    @scheduled_at.present?
  end

  def idempotency_key
    "idempotency:status:#{@account.id}:#{@options[:idempotency]}"
  end

  def idempotency_given?
    @options[:idempotency].present?
  end

  def idempotency_duplicate
    if scheduled?
      @account.scheduled_statuses.find(@idempotency_duplicate)
    else
      @account.statuses.find(@idempotency_duplicate)
    end
  end

  def idempotency_duplicate?
    @idempotency_duplicate = redis.get(idempotency_key)
  end

  def scheduled_in_the_past?
    @scheduled_at.present? && @scheduled_at <= Time.now.utc
  end

  def bump_potential_friendship!
    return if !@status.reply? || @account.id == @status.in_reply_to_account_id

    ActivityTracker.increment('activity:interactions')
  end

  def status_attributes
    {
      text: @text,
      media_attachments: @media || [],
      ordered_media_attachment_ids: (@options[:media_ids] || []).map(&:to_i) & @media.map(&:id),
      thread: @in_reply_to,
      status_reference_ids: @status_reference_ids,
      poll_attributes: poll_attributes,
      sensitive: @sensitive,
      spoiler_text: @options[:spoiler_text] || '',
      markdown: @markdown,
      visibility: @visibility,
      limited_scope: @limited_scope || :none,
      searchability: @searchability,
      language: valid_locale_cascade(@options[:language], @account.user&.preferred_posting_language, I18n.default_locale),
      application: @options[:application],
      rate_limit: @options[:with_rate_limit],
    }.compact
  end

  def scheduled_status_attributes
    {
      scheduled_at: @scheduled_at,
      media_attachments: @media || [],
      params: scheduled_options,
    }
  end

  def poll_attributes
    return if @options[:poll].blank?

    @options[:poll].merge(account: @account, voters_count: 0)
  end

  def scheduled_options
    @options.dup.tap do |options_hash|
      options_hash[:in_reply_to_id]  = options_hash.delete(:thread)&.id
      options_hash[:application_id]  = options_hash.delete(:application)&.id
      options_hash[:scheduled_at]    = nil
      options_hash[:idempotency]     = nil
      options_hash[:with_rate_limit] = false
    end
  end
end
