# frozen_string_literal: true

class ActivityPub::ProcessStatusUpdateService < BaseService
  include JsonLdHelper
  include Redisable
  include Lockable
  include NgRuleHelper

  class AbortError < ::StandardError; end

  def call(status, activity_json, object_json, request_id: nil)
    raise ArgumentError, 'Status has unsaved changes' if status.changed?

    @activity_json             = activity_json
    @json                      = object_json
    @status_parser             = ActivityPub::Parser::StatusParser.new(@json, account: status.account)
    @uri                       = @status_parser.uri
    @status                    = status
    @account                   = status.account
    @media_attachments_changed = false
    @poll_changed              = false
    @request_id                = request_id

    # Only native types can be updated at the moment
    return @status if !expected_type? || already_updated_more_recently?

    if @status_parser.edited_at.present? && (@status.edited_at.nil? || @status_parser.edited_at > @status.edited_at)
      read_metadata
      return @status unless valid_status?

      handle_explicit_update!
    else
      handle_implicit_update!
    end

    @status
  rescue AbortError
    @status.reload
    @status
  end

  private

  def handle_explicit_update!
    last_edit_date = @status.edited_at.presence || @status.created_at

    # Only allow processing one create/update per status at a time
    with_redis_lock("create:#{@uri}") do
      Status.transaction do
        record_previous_edit!
        update_media_attachments!
        update_poll!
        update_immediate_attributes!
        update_metadata!
        validate_status_mentions!
        create_edits!
      end

      update_references!
      download_media_files!
      queue_poll_notifications!

      next unless significant_changes?

      reset_preview_card!
      broadcast_updates!
    end

    forward_activity! if significant_changes? && @status_parser.edited_at > last_edit_date
  end

  def handle_implicit_update!
    with_redis_lock("create:#{@uri}") do
      update_poll!(allow_significant_changes: false)
      queue_poll_notifications!
    end
  end

  def update_media_attachments!
    previous_media_attachments     = @status.media_attachments.to_a
    previous_media_attachments_ids = @status.ordered_media_attachment_ids || previous_media_attachments.map(&:id)
    @next_media_attachments        = []

    as_array(@json['attachment']).each do |attachment|
      media_attachment_parser = ActivityPub::Parser::MediaAttachmentParser.new(attachment)

      next if media_attachment_parser.remote_url.blank? || @next_media_attachments.size > Status::MEDIA_ATTACHMENTS_LIMIT_FROM_REMOTE

      begin
        media_attachment   = previous_media_attachments.find { |previous_media_attachment| previous_media_attachment.remote_url == media_attachment_parser.remote_url }
        media_attachment ||= MediaAttachment.new(account: @account, remote_url: media_attachment_parser.remote_url)

        # If a previously existing media attachment was significantly updated, mark
        # media attachments as changed even if none were added or removed
        @media_attachments_changed = true if media_attachment_parser.significantly_changes?(media_attachment)

        media_attachment.description          = media_attachment_parser.description
        media_attachment.focus                = media_attachment_parser.focus
        media_attachment.thumbnail_remote_url = media_attachment_parser.thumbnail_remote_url
        media_attachment.blurhash             = media_attachment_parser.blurhash
        media_attachment.status_id            = @status.id
        media_attachment.skip_download        = unsupported_media_type?(media_attachment_parser.file_content_type) || skip_download?
        media_attachment.save!

        @next_media_attachments << media_attachment
      rescue Addressable::URI::InvalidURIError => e
        Rails.logger.debug { "Invalid URL in attachment: #{e}" }
      end
    end

    @status.ordered_media_attachment_ids = @next_media_attachments.map(&:id)

    @media_attachments_changed = true if @status.ordered_media_attachment_ids != previous_media_attachments_ids
  end

  def download_media_files!
    @next_media_attachments.each do |media_attachment|
      next if media_attachment.skip_download

      media_attachment.download_file! if media_attachment.remote_url_previously_changed?
      media_attachment.download_thumbnail! if media_attachment.thumbnail_remote_url_previously_changed?
      media_attachment.save
    rescue Mastodon::UnexpectedResponseError, HTTP::TimeoutError, HTTP::ConnectionError, OpenSSL::SSL::SSLError
      RedownloadMediaWorker.perform_in(rand(30..600).seconds, media_attachment.id)
    rescue Seahorse::Client::NetworkingError => e
      Rails.logger.warn "Error storing media attachment: #{e}"
    end

    @status.media_attachments.reload
  end

  def update_poll!(allow_significant_changes: true)
    previous_poll        = @status.preloadable_poll
    @previous_expires_at = previous_poll&.expires_at
    poll_parser          = ActivityPub::Parser::PollParser.new(@json)

    if poll_parser.valid?
      poll = previous_poll || @account.polls.new(status: @status)

      # If for some reasons the options were changed, it invalidates all previous
      # votes, so we need to remove them
      @poll_changed = true if poll_parser.significantly_changes?(poll)
      return if @poll_changed && !allow_significant_changes

      poll.last_fetched_at = Time.now.utc
      poll.options         = poll_parser.options
      poll.multiple        = poll_parser.multiple
      poll.expires_at      = poll_parser.expires_at
      poll.voters_count    = poll_parser.voters_count
      poll.cached_tallies  = poll_parser.cached_tallies
      poll.reset_votes! if @poll_changed
      poll.save!

      @status.poll_id = poll.id
    elsif previous_poll.present?
      return unless allow_significant_changes

      previous_poll.destroy!
      @poll_changed = true
      @status.poll_id = nil
    end
  end

  def valid_status?
    valid = !Admin::NgWord.reject?("#{@status_parser.spoiler_text}\n#{@status_parser.text}", uri: @status.uri, target_type: :status, stranger: mention_to_local_stranger? || reference_to_local_stranger?)
    valid = !Admin::NgWord.hashtag_reject?(@raw_tags.size) if valid
    valid = false if valid && Admin::NgWord.mention_reject?(@raw_mentions.size, uri: @status.uri, target_type: :status, text: "#{@status_parser.spoiler_text}\n#{@status_parser.text}")
    valid = false if valid && (mention_to_local_stranger? || reference_to_local_stranger?) && Admin::NgWord.stranger_mention_reject_with_count?(@raw_mentions.size, uri: @status.uri, target_type: :status, text: "#{@status_parser.spoiler_text}\n#{@status_parser.text}")
    valid = false if valid && (mention_to_local_stranger? || reference_to_local_stranger?) && reject_reply_exclude_followers?

    valid
  end

  def validate_status_mentions!
    raise AbortError unless valid_status_for_ng_rule?
  end

  def valid_status_for_ng_rule?
    check_invalid_status_for_ng_rule! @account,
                                      reaction_type: 'edit',
                                      uri: @status.uri,
                                      url: @status_parser.url || @status.url,
                                      spoiler_text: @status.spoiler_text,
                                      text: @status.text,
                                      tag_names: @raw_tags,
                                      visibility: @status.visibility,
                                      searchability: @status.searchability,
                                      sensitive: @status.sensitive,
                                      media_count: @next_media_attachments.size,
                                      poll_count: @status.poll&.options&.size || 0,
                                      quote: quote,
                                      reply: @status.reply?,
                                      mention_count: @status.mentions.count,
                                      reference_count: reference_uris.size,
                                      mention_to_following: !(mention_to_local_stranger? || reference_to_local_stranger?)
  end

  def mention_to_local_stranger?
    return @mention_to_local_stranger if defined?(@mention_to_local_stranger)

    @mention_to_local_stranger = @raw_mentions.filter_map { |uri| ActivityPub::TagManager.instance.local_uri?(uri) && ActivityPub::TagManager.instance.uri_to_resource(uri, Account) }.any? { |mentioned_account| !mentioned_account.following?(@status.account) }
    @mention_to_local_stranger ||= @status.thread.present? && @status.thread.account_id != @status.account_id && @status.thread.account.local? && !@status.thread.account.following?(@status.account)
    @mention_to_local_stranger
  end

  def reference_to_local_stranger?
    local_referred_accounts.any? { |account| !account.following?(@account) }
  end

  def update_immediate_attributes!
    @status.text         = @status_parser.text || ''
    @status.spoiler_text = @status_parser.spoiler_text || ''
    @status.sensitive    = @account.sensitized? || @status_parser.sensitive || false
    @status.language     = @status_parser.language

    process_sensitive_words

    @significant_changes = text_significantly_changed? || @status.spoiler_text_changed? || @media_attachments_changed || @poll_changed

    @status.edited_at = @status_parser.edited_at if significant_changes?

    @status.save!
  end

  def process_sensitive_words
    return unless %i(public public_unlisted login).include?(@status.visibility.to_sym) && Admin::SensitiveWord.sensitive?(@status.text, @status.spoiler_text, local: false)

    @status.text = Admin::SensitiveWord.modified_text(@status.text, @status.spoiler_text)
    @status.spoiler_text = Admin::SensitiveWord.alternative_text
    @status.sensitive = true
  end

  def read_metadata
    @raw_tags     = []
    @raw_mentions = []
    @raw_emojis   = []

    as_array(@json['tag']).each do |tag|
      if equals_or_includes?(tag['type'], 'Hashtag')
        @raw_tags << tag['name'] if !ignore_hashtags? && tag['name'].present?
      elsif equals_or_includes?(tag['type'], 'Mention')
        @raw_mentions << tag['href'] if tag['href'].present?
      elsif equals_or_includes?(tag['type'], 'Emoji')
        @raw_emojis << tag
      end
    end
  end

  def update_metadata!
    update_tags!
    update_mentions!
    update_emojis!
  end

  def update_tags!
    @status.tags = Tag.find_or_create_by_names(@raw_tags)
  end

  def update_mentions!
    previous_mentions = @status.active_mentions.includes(:account).to_a
    current_mentions  = []

    @raw_mentions.each do |href|
      next if href.blank?

      account   = ActivityPub::TagManager.instance.uri_to_resource(href, Account)
      account ||= ActivityPub::FetchRemoteAccountService.new.call(href, request_id: @request_id)

      next if account.nil?

      mention   = previous_mentions.find { |x| x.account_id == account.id }
      mention ||= account.mentions.new(status: @status)

      current_mentions << mention
    end

    current_mentions.each do |mention|
      mention.save if mention.new_record?
    end

    # If previous mentions are no longer contained in the text, convert them
    # to silent mentions, since withdrawing access from someone who already
    # received a notification might be more confusing
    removed_mentions = previous_mentions - current_mentions

    Mention.where(id: removed_mentions.map(&:id)).update_all(silent: true) unless removed_mentions.empty?
  end

  def update_emojis!
    return if skip_download?

    @raw_emojis.each do |raw_emoji|
      custom_emoji_parser = ActivityPub::Parser::CustomEmojiParser.new(raw_emoji)

      next if custom_emoji_parser.shortcode.blank? || custom_emoji_parser.image_remote_url.blank?

      emoji = CustomEmoji.find_by(shortcode: custom_emoji_parser.shortcode, domain: @account.domain)

      next unless emoji.nil? ||
                  custom_emoji_parser.image_remote_url != emoji.image_remote_url ||
                  (custom_emoji_parser.updated_at && custom_emoji_parser.updated_at >= emoji.updated_at) ||
                  custom_emoji_parser.license != emoji.license

      begin
        emoji ||= CustomEmoji.new(domain: @account.domain, shortcode: custom_emoji_parser.shortcode, uri: custom_emoji_parser.uri)
        emoji.image_remote_url = custom_emoji_parser.image_remote_url
        emoji.license = custom_emoji_parser.license
        emoji.is_sensitive = custom_emoji_parser.is_sensitive
        emoji.aliases = custom_emoji_parser.aliases
        emoji.save
      rescue Seahorse::Client::NetworkingError => e
        Rails.logger.warn "Error storing emoji: #{e}"
      end
    end
  end

  def update_references!
    references = reference_uris

    ProcessReferencesService.call_service_without_error(@status, [], references, [quote].compact)
  end

  def reference_uris
    return @reference_uris if defined?(@reference_uris)

    @reference_uris = @json['references'].nil? ? [] : (ActivityPub::FetchReferencesService.new.call(@status.account, @json['references']) || [])
    @reference_uris += ProcessReferencesService.extract_uris(@json['content'] || '')
  end

  def quote
    @json['quote'] || @json['quoteUrl'] || @json['quoteURL'] || @json['_misskey_quote']
  end

  def local_referred_accounts
    return @local_referred_accounts if defined?(@local_referred_accounts)

    local_referred_statuses = reference_uris.filter_map do |uri|
      ActivityPub::TagManager.instance.local_uri?(uri) && ActivityPub::TagManager.instance.uri_to_resource(uri, Status)
    end.compact

    @local_referred_accounts = local_referred_statuses.map(&:account)
  end

  def expected_type?
    equals_or_includes_any?(@json['type'], %w(Note Question))
  end

  def record_previous_edit!
    @previous_edit = @status.build_snapshot(at_time: @status.created_at, rate_limit: false) if @status.edits.empty?
  end

  def create_edits!
    return unless significant_changes?

    @previous_edit&.save!
    @status.snapshot!(account_id: @account.id, rate_limit: false)
  end

  def skip_download?
    return @skip_download if defined?(@skip_download)

    @skip_download ||= DomainBlock.reject_media?(@account.domain)
  end

  def ignore_hashtags?
    return @ignore_hashtags if defined?(@ignore_hashtags)

    @ignore_hashtags ||= DomainBlock.reject_hashtag?(@account.domain)
  end

  def reject_reply_exclude_followers?
    return @reject_reply_exclude_followers if defined?(@reject_reply_exclude_followers)

    @reject_reply_exclude_followers ||= DomainBlock.reject_reply_exclude_followers?(@account.domain)
  end

  def unsupported_media_type?(mime_type)
    mime_type.present? && !MediaAttachment.supported_mime_types.include?(mime_type)
  end

  def significant_changes?
    @significant_changes
  end

  def text_significantly_changed?
    return false unless @status.text_changed?

    old, new = @status.text_change
    HtmlAwareFormatter.new(old, false).to_s != HtmlAwareFormatter.new(new, false).to_s
  end

  def already_updated_more_recently?
    @status.edited_at.present? && @status_parser.edited_at.present? && @status.edited_at > @status_parser.edited_at
  end

  def reset_preview_card!
    @status.reset_preview_card!
    LinkCrawlWorker.perform_in(rand(1..59).seconds, @status.id)
  end

  def broadcast_updates!
    ::DistributionWorker.perform_async(@status.id, { 'update' => true })
  end

  def queue_poll_notifications!
    poll = @status.preloadable_poll

    # If the poll had no expiration date set but now has, or now has a sooner
    # expiration date, and people have voted, schedule a notification

    return unless poll.present? && poll.expires_at.present? && poll.votes.exists?

    PollExpirationNotifyWorker.remove_from_scheduled(poll.id) if @previous_expires_at.present? && @previous_expires_at > poll.expires_at
    PollExpirationNotifyWorker.perform_at(poll.expires_at + 5.minutes, poll.id)
  end

  def forward_activity!
    forwarder.forward! if forwarder.forwardable?
  end

  def forwarder
    @forwarder ||= ActivityPub::Forwarder.new(@account, @activity_json, @status)
  end
end
