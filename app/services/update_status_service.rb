# frozen_string_literal: true

class UpdateStatusService < BaseService
  include Redisable
  include LanguagesHelper
  include NgRuleHelper

  class NoChangesSubmittedError < StandardError; end

  # @param [Status] status
  # @param [Integer] account_id
  # @param [Hash] options
  # @option options [Array<Integer>] :media_ids
  # @option options [Array<Hash>] :media_attributes
  # @option options [Hash] :poll
  # @option options [String] :text
  # @option options [String] :spoiler_text
  # @option options [Boolean] :sensitive
  # @option options [Boolean] :markdown
  # @option options [String] :language
  # @option [Enumerable] :status_reference_ids Optional array
  def call(status, account_id, options = {})
    @status                    = status
    @options                   = options
    @account_id                = account_id
    @media_attachments_changed = false
    @poll_changed              = false
    @old_sensitive             = sensitive?

    clear_histories! if @options[:no_history]

    validate_status!

    Status.transaction do
      validate_status_ng_rules!

      create_previous_edit! unless @options[:no_history]
      update_media_attachments! if @options.key?(:media_ids)
      update_poll! if @options.key?(:poll)
      update_immediate_attributes!
      create_edit! unless @options[:no_history]

      reset_preview_card!
      process_mentions_service.call(@status)
      validate_status_mentions!
    end

    queue_poll_notifications!
    update_metadata!
    update_references!
    broadcast_updates!

    # Mentions are not updated (Cause unknown)
    @status.reload

    @status
  rescue NoChangesSubmittedError
    # For calls that result in no changes, swallow the error
    # but get back to the original state

    @status.reload
  end

  private

  def update_media_attachments!
    previous_media_attachments = @status.ordered_media_attachments.to_a
    next_media_attachments     = validate_media!
    added_media_attachments    = next_media_attachments - previous_media_attachments

    (@options[:media_attributes] || []).each do |attributes|
      media = next_media_attachments.find { |attachment| attachment.id == attributes[:id].to_i }
      next if media.nil?

      media.update!(attributes.slice(:thumbnail, :description, :focus))
      @media_attachments_changed ||= media.significantly_changed?
    end

    MediaAttachment.where(id: added_media_attachments.map(&:id)).update_all(status_id: @status.id)

    @status.ordered_media_attachment_ids = (@options[:media_ids] || []).map(&:to_i) & next_media_attachments.map(&:id)
    @media_attachments_changed ||= previous_media_attachments.map(&:id) != @status.ordered_media_attachment_ids
    @status.media_attachments.reload
  end

  def validate_status!
    return if @options[:bypass_validation]
    raise Mastodon::ValidationError, I18n.t('statuses.contains_ng_words') if Admin::NgWord.reject?("#{@options[:spoiler_text]}\n#{@options[:text]}")
    raise Mastodon::ValidationError, I18n.t('statuses.too_many_hashtags') if Admin::NgWord.hashtag_reject_with_extractor?(@options[:text] || '')
    raise Mastodon::ValidationError, I18n.t('statuses.too_many_mentions') if Admin::NgWord.mention_reject_with_extractor?(@options[:text] || '')
    raise Mastodon::ValidationError, I18n.t('statuses.too_many_mentions') if (mention_to_stranger? || reference_to_stranger?) && Admin::NgWord.stranger_mention_reject_with_extractor?(@options[:text] || '')
  end

  def validate_status_mentions!
    return if @options[:bypass_validation]
    raise Mastodon::ValidationError, I18n.t('statuses.contains_ng_words') if (mention_to_stranger? || reference_to_stranger?) && Setting.stranger_mention_from_local_ng && Admin::NgWord.stranger_mention_reject?("#{@options[:spoiler_text]}\n#{@options[:text]}")
  end

  def validate_status_ng_rules!
    return if @options[:bypass_validation]

    result = check_invalid_status_for_ng_rule! @status.account,
                                               reaction_type: 'edit',
                                               spoiler_text: @options.key?(:spoiler_text) ? (@options[:spoiler_text] || '') : @status.spoiler_text,
                                               text: text,
                                               tag_names: Extractor.extract_hashtags(text) || [],
                                               visibility: @status.visibility,
                                               searchability: @status.searchability,
                                               sensitive: @options.key?(:sensitive) ? @options[:sensitive] : @status.sensitive,
                                               media_count: @options[:media_ids].present? ? @options[:media_ids].size : @status.media_attachments.count,
                                               poll_count: @options.dig(:poll, 'options')&.size || 0,
                                               quote: quote_url,
                                               reply: @status.reply?,
                                               mention_count: mention_count,
                                               reference_count: reference_urls.size,
                                               mention_to_following: !(mention_to_stranger? || reference_to_stranger?)

    raise Mastodon::ValidationError, I18n.t('statuses.violate_rules') unless result
  end

  def mention_count
    text.gsub(Account::MENTION_RE)&.count || 0
  end

  def mention_to_stranger?
    @status.mentions.map(&:account).to_a.any? { |mentioned_account| !mentioned_account.following_or_self?(@status.account) } ||
      (@status.thread.present? && !@status.thread.account.following_or_self?(@status.account))
  end

  def reference_to_stranger?
    referred_statuses.any? { |status| !status.account.following_or_self?(@status.account) }
  end

  def referred_statuses
    return [] unless text

    reference_urls.filter_map { |uri| ActivityPub::TagManager.instance.local_uri?(uri) && ActivityPub::TagManager.instance.uri_to_resource(uri, Status, url: true) }
  end

  def quote_url
    ProcessReferencesService.extract_quote(text)
  end

  def reference_urls
    @reference_urls ||= ProcessReferencesService.extract_uris(text) || []
  end

  def text
    @options.key?(:text) ? (@options[:text] || '') : @status.text
  end

  def validate_media!
    return [] if @options[:media_ids].blank? || !@options[:media_ids].is_a?(Enumerable)

    media_max = @options[:poll] ? Status::MEDIA_ATTACHMENTS_LIMIT_WITH_POLL : Status::MEDIA_ATTACHMENTS_LIMIT

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.too_many') if @options[:media_ids].size > media_max

    media_attachments = @status.account.media_attachments.where(status_id: [nil, @status.id]).where(scheduled_status_id: nil).where(id: @options[:media_ids].take(media_max).map(&:to_i)).to_a

    not_found_ids = @options[:media_ids].map(&:to_i) - media_attachments.map(&:id)
    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.not_found', ids: not_found_ids.join(', ')) if not_found_ids.any?

    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.images_and_video') if media_attachments.size > 1 && media_attachments.find(&:audio_or_video?)
    raise Mastodon::ValidationError, I18n.t('media_attachments.validations.not_ready') if media_attachments.any?(&:not_processed?)

    media_attachments
  end

  def update_poll!
    previous_poll        = @status.preloadable_poll
    @previous_expires_at = previous_poll&.expires_at

    if @options[:poll].present?
      poll = previous_poll || @status.account.polls.new(status: @status, votes_count: 0)

      # If for some reasons the options were changed, it invalidates all previous
      # votes, so we need to remove them
      @poll_changed = true if @options[:poll][:options] != poll.options || ActiveModel::Type::Boolean.new.cast(@options[:poll][:multiple]) != poll.multiple

      poll.options     = @options[:poll][:options]
      poll.hide_totals = @options[:poll][:hide_totals] || false
      poll.multiple    = @options[:poll][:multiple] || false
      poll.expires_in  = @options[:poll][:expires_in]
      poll.reset_votes! if @poll_changed
      poll.save!

      @status.poll_id = poll.id
    elsif previous_poll.present?
      previous_poll.destroy
      @poll_changed = true
      @status.poll_id = nil
    end

    @poll_changed = true if @previous_expires_at != @status.preloadable_poll&.expires_at
  end

  def update_immediate_attributes!
    @status.text         = @options[:text].presence || @options.delete(:spoiler_text) || '' if @options.key?(:text)
    @status.spoiler_text = @options[:spoiler_text] || '' if @options.key?(:spoiler_text)
    @status.markdown     = @options[:markdown] || false
    @status.sensitive    = @options[:sensitive] || @options[:spoiler_text].present? if @options.key?(:sensitive) || @options.key?(:spoiler_text)
    @status.language     = valid_locale_cascade(@options[:language], @status.language, @status.account.user&.preferred_posting_language, I18n.default_locale)
    process_sensitive_words

    # We raise here to rollback the entire transaction
    raise NoChangesSubmittedError unless significant_changes?

    update_expiration!

    @status.edited_at = Time.now.utc
    @status.save!
  end

  def process_sensitive_words
    return unless [:public, :public_unlisted, :login].include?(@status.visibility&.to_sym) && Admin::SensitiveWord.sensitive?(@status.text, @status.spoiler_text || '')

    @status.text = Admin::SensitiveWord.modified_text(@status.text, @status.spoiler_text)
    @status.spoiler_text = Admin::SensitiveWord.alternative_text
    @status.sensitive = true
  end

  def update_expiration!
    UpdateStatusExpirationService.new.call(@status)
  end

  def reset_preview_card!
    return unless @status.text_previously_changed?

    @status.reset_preview_card!
    LinkCrawlWorker.perform_async(@status.id)
  end

  def update_references!
    reference_ids = (@options[:status_reference_ids] || []).map(&:to_i).filter(&:positive?)

    ProcessReferencesService.call_service(@status, reference_ids, [])
  end

  def update_metadata!
    ProcessHashtagsService.new.call(@status)

    @status.update(limited_scope: :circle) if process_mentions_service.mentions?
  end

  def process_mentions_service
    @process_mentions_service ||= ProcessMentionsService.new
  end

  def broadcast_updates!
    DistributionWorker.perform_async(@status.id, { 'update' => true })
    ActivityPub::StatusUpdateDistributionWorker.perform_async(@status.id, { 'sensitive' => sensitive?, 'sensitive_changed' => @old_sensitive != sensitive? && sensitive? })
  end

  def queue_poll_notifications!
    poll = @status.preloadable_poll

    # If the poll had no expiration date set but now has, or now has a sooner
    # expiration date, schedule a notification

    return unless poll.present? && poll.expires_at.present?

    PollExpirationNotifyWorker.remove_from_scheduled(poll.id) if @previous_expires_at.present? && @previous_expires_at > poll.expires_at
    PollExpirationNotifyWorker.perform_at(poll.expires_at + 5.minutes, poll.id)
  end

  def create_previous_edit!
    # We only need to create a previous edit when no previous edits exist, e.g.
    # when the status has never been edited. For other cases, we always create
    # an edit, so the step can be skipped

    return if @status.edits.any?

    @status.snapshot!(at_time: @status.created_at, rate_limit: false)
  end

  def create_edit!
    @status.snapshot!(account_id: @account_id)
  end

  def significant_changes?
    @status.changed? || @poll_changed || @media_attachments_changed
  end

  def clear_histories!
    @status.edits.destroy_all
    @status.edited_at = nil
    @status.save!
  end

  def sensitive?
    @status.sensitive
  end
end
