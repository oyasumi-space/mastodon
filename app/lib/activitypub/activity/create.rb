# frozen_string_literal: true

class ActivityPub::Activity::Create < ActivityPub::Activity
  include FormattingHelper
  include NgRuleHelper

  def perform
    @account.schedule_refresh_if_stale!

    dereference_object!

    create_status
  end

  private

  def create_status
    return reject_payload! if unsupported_object_type? || non_matching_uri_hosts?(@account.uri, object_uri) || tombstone_exists? || !related_to_local_activity?

    if @account.suspended?
      process_pending_status if @account.remote_pending?
      return
    end

    with_redis_lock("create:#{object_uri}") do
      return if delete_arrived_first?(object_uri) || poll_vote?

      @status = find_existing_status

      if @status.nil?
        process_status
      elsif @options[:delivered_to_account_id].present?
        postprocess_audience_and_deliver
      end
    end

    @status || reject_payload!
  end

  def audience_to
    as_array(@object['to'] || @json['to']).map { |x| value_or_id(x) }
  end

  def audience_cc
    as_array(@object['cc'] || @json['cc']).map { |x| value_or_id(x) }
  end

  def process_status
    @tags                 = []
    @mentions             = []
    @unresolved_mentions  = []
    @silenced_account_ids = []
    @params               = {}
    @raw_mention_uris     = []

    process_status_params
    process_sensitive_words
    process_tags
    process_audience

    return nil unless valid_status?
    return nil if (mention_to_local_stranger? || reference_to_local_stranger?) && reject_reply_exclude_followers?

    ApplicationRecord.transaction do
      @status = Status.create!(@params)
      attach_tags(@status)
    end

    resolve_thread(@status)
    resolve_unresolved_mentions(@status)
    fetch_replies(@status)
    process_conversation! if @status.limited_visibility?
    process_references!
    distribute
    forward_for_reply
  end

  def distribute
    # Spread out crawling randomly to avoid DDoSing the link
    LinkCrawlWorker.perform_in(rand(1..59).seconds, @status.id)

    # Distribute into home and list feeds and notify mentioned accounts
    ::DistributionWorker.perform_async(@status.id, { 'silenced_account_ids' => @silenced_account_ids }) if @options[:override_timestamps] || @status.within_realtime_window?
  end

  def find_existing_status
    status   = status_from_uri(object_uri)
    status ||= Status.find_by(uri: @object['atomUri']) if @object['atomUri'].present?
    status if status&.account_id == @account.id
  end

  def process_status_params
    @status_parser = ActivityPub::Parser::StatusParser.new(@json, followers_collection: @account.followers_url, object: @object, account: @account, friend_domain: friend_domain?)

    attachment_ids = process_attachments.take(Status::MEDIA_ATTACHMENTS_LIMIT_FROM_REMOTE).map(&:id)

    @params = {
      uri: @status_parser.uri,
      url: @status_parser.url || @status_parser.uri,
      account: @account,
      text: converted_object_type? ? converted_text : (@status_parser.text || ''),
      language: @status_parser.language,
      spoiler_text: converted_object_type? ? '' : (@status_parser.spoiler_text || ''),
      created_at: @status_parser.created_at,
      edited_at: @status_parser.edited_at && @status_parser.edited_at != @status_parser.created_at ? @status_parser.edited_at : nil,
      override_timestamps: @options[:override_timestamps],
      reply: @status_parser.reply,
      sensitive: @account.sensitized? || @status_parser.sensitive || false,
      visibility: @status_parser.visibility,
      limited_scope: @status_parser.limited_scope,
      searchability: @status_parser.searchability,
      thread: replied_to_status,
      conversation: conversation_from_activity,
      media_attachment_ids: attachment_ids,
      ordered_media_attachment_ids: attachment_ids,
      poll: process_poll,
    }
  end

  def process_sensitive_words
    return unless %i(public public_unlisted login).include?(@params[:visibility].to_sym) && Admin::SensitiveWord.sensitive?(@params[:text], @params[:spoiler_text], local: false)

    @params[:text] = Admin::SensitiveWord.modified_text(@params[:text], @params[:spoiler_text])
    @params[:spoiler_text] = Admin::SensitiveWord.alternative_text
    @params[:sensitive] = true
  end

  def valid_status?
    valid = true
    valid = false if valid && !valid_status_for_ng_rule?
    valid = !Admin::NgWord.reject?("#{@params[:spoiler_text]}\n#{@params[:text]}", uri: @params[:uri], target_type: :status, public: @status_parser.distributable_visibility?, stranger: mention_to_local_stranger? || reference_to_local_stranger?) if valid
    valid = !Admin::NgWord.hashtag_reject?(@tags.size, uri: @params[:uri], target_type: :status, public: @status_parser.distributable_visibility?, text: "#{@params[:spoiler_text]}\n#{@params[:text]}") if valid
    valid = !Admin::NgWord.mention_reject?(@raw_mention_uris.size, uri: @params[:uri], target_type: :status, public: @status_parser.distributable_visibility?, text: "#{@params[:spoiler_text]}\n#{@params[:text]}") if valid
    if valid && (mention_to_local_stranger? || reference_to_local_stranger?)
      valid = !Admin::NgWord.stranger_mention_reject_with_count?(@raw_mention_uris.size, uri: @params[:uri], target_type: :status, public: @status_parser.distributable_visibility?,
                                                                                         text: "#{@params[:spoiler_text]}\n#{@params[:text]}")
    end

    valid
  end

  def valid_status_for_ng_rule?
    check_invalid_status_for_ng_rule! @account,
                                      reaction_type: 'create',
                                      uri: @params[:uri],
                                      url: @params[:url],
                                      spoiler_text: @params[:spoiler_text],
                                      text: @params[:text],
                                      tag_names: @tags.map(&:name),
                                      visibility: @params[:visibility].to_s,
                                      searchability: @params[:searchability]&.to_s,
                                      sensitive: @params[:sensitive],
                                      media_count: @params[:media_attachment_ids]&.size,
                                      poll_count: @params[:poll]&.options&.size || 0,
                                      quote: quote,
                                      reply: in_reply_to_uri.present?,
                                      mention_count: mentioned_accounts.count,
                                      reference_count: reference_uris.size,
                                      mention_to_following: !(mention_to_local_stranger? || reference_to_local_stranger?)
  end

  def accounts_in_audience
    return @accounts_in_audience if @accounts_in_audience

    # Unlike with tags, there is no point in resolving accounts we don't already
    # know here, because silent mentions would only be used for local access control anyway
    accounts_in_audience = (audience_to + audience_cc).uniq.filter_map do |audience|
      account_from_uri(audience) unless ActivityPub::TagManager.instance.public_collection?(audience)
    end

    # If the payload was delivered to a specific inbox, the inbox owner must have
    # access to it, unless they already have access to it anyway
    if @options[:delivered_to_account_id]
      accounts_in_audience << delivered_to_account
      accounts_in_audience.uniq!
    end

    @accounts_in_audience = accounts_in_audience
  end

  def process_audience
    accounts_in_audience.each do |account|
      # This runs after tags are processed, and those translate into non-silent
      # mentions, which take precedence
      next if @mentions.any? { |mention| mention.account_id == account.id }

      @mentions << Mention.new(account: account, silent: true)

      # If there is at least one silent mention, then the status can be considered
      # as a limited-audience status, and not strictly a direct message, but only
      # if we considered a direct message in the first place
      @params[:visibility] = :limited if @params[:visibility] == :direct
    end

    # Accounts that are tagged but are not in the audience are not
    # supposed to be notified explicitly
    @silenced_account_ids = @mentions.map(&:account_id) - accounts_in_audience.map(&:id)
  end

  def account_representative
    accounts_in_audience.detect(&:local?) || Account.representative
  end

  def postprocess_audience_and_deliver
    return if @status.mentions.find_by(account_id: @options[:delivered_to_account_id])

    @status.mentions.create(account: delivered_to_account, silent: true)
    @status.update(visibility: :limited) if @status.direct_visibility?

    return unless delivered_to_account.following?(@account)

    FeedInsertWorker.perform_async(@status.id, delivered_to_account.id, 'home')
  end

  def delivered_to_account
    @delivered_to_account ||= Account.find(@options[:delivered_to_account_id])
  end

  def attach_tags(status)
    @tags.each do |tag|
      status.tags << tag
      tag.update(last_status_at: status.created_at) if tag.last_status_at.nil? || (tag.last_status_at < status.created_at && tag.last_status_at < 12.hours.ago)
    end

    # If we're processing an old status, this may register tags as being used now
    # as opposed to when the status was really published, but this is probably
    # not a big deal
    Trends.tags.register(status)

    @mentions.each do |mention|
      mention.status = status
      mention.save
    end
  end

  def process_tags
    return if @object['tag'].nil?

    as_array(@object['tag']).each do |tag|
      if equals_or_includes?(tag['type'], 'Hashtag')
        process_hashtag tag
      elsif equals_or_includes?(tag['type'], 'Mention')
        process_mention tag
      elsif equals_or_includes?(tag['type'], 'Emoji')
        process_emoji tag
      end
    end
  end

  def process_hashtag(tag)
    return if tag['name'].blank? || ignore_hashtags?

    Tag.find_or_create_by_names(tag['name']) do |hashtag|
      @tags << hashtag unless @tags.include?(hashtag) || !hashtag.valid?
    end
  rescue ActiveRecord::RecordInvalid
    nil
  end

  def process_mention(tag)
    return if tag['href'].blank?

    @raw_mention_uris << tag['href']

    account = account_from_uri(tag['href'])
    account = ActivityPub::FetchRemoteAccountService.new.call(tag['href'], request_id: @options[:request_id]) if account.nil?

    return if account.nil?

    @mentions << Mention.new(account: account, silent: false)
  rescue Mastodon::UnexpectedResponseError, HTTP::TimeoutError, HTTP::ConnectionError, OpenSSL::SSL::SSLError
    @unresolved_mentions << tag['href']
  end

  def process_emoji(tag)
    return if skip_download?

    custom_emoji_parser = ActivityPub::Parser::CustomEmojiParser.new(tag)

    return if custom_emoji_parser.shortcode.blank? || custom_emoji_parser.image_remote_url.blank?

    emoji = CustomEmoji.find_by(shortcode: custom_emoji_parser.shortcode, domain: @account.domain)

    return unless emoji.nil? ||
                  custom_emoji_parser.image_remote_url != emoji.image_remote_url ||
                  (custom_emoji_parser.updated_at && custom_emoji_parser.updated_at >= emoji.updated_at) ||
                  custom_emoji_parser.license != emoji.license

    begin
      emoji ||= CustomEmoji.new(
        domain: @account.domain,
        shortcode: custom_emoji_parser.shortcode,
        uri: custom_emoji_parser.uri
      )
      emoji.image_remote_url = custom_emoji_parser.image_remote_url
      emoji.license = custom_emoji_parser.license
      emoji.is_sensitive = custom_emoji_parser.is_sensitive
      emoji.aliases = custom_emoji_parser.aliases
      emoji.save
    rescue Seahorse::Client::NetworkingError => e
      Rails.logger.warn "Error storing emoji: #{e}"
    end
  end

  def process_attachments
    return [] if @object['attachment'].nil?

    media_attachments = []

    as_array(@object['attachment']).each do |attachment|
      media_attachment_parser = ActivityPub::Parser::MediaAttachmentParser.new(attachment)

      next if media_attachment_parser.remote_url.blank? || media_attachments.size >= Status::MEDIA_ATTACHMENTS_LIMIT_FROM_REMOTE

      begin
        media_attachment = MediaAttachment.create(
          account: @account,
          remote_url: media_attachment_parser.remote_url,
          thumbnail_remote_url: media_attachment_parser.thumbnail_remote_url,
          description: media_attachment_parser.description,
          focus: media_attachment_parser.focus,
          blurhash: media_attachment_parser.blurhash
        )

        media_attachments << media_attachment

        next if unsupported_media_type?(media_attachment_parser.file_content_type) || skip_download?

        media_attachment.download_file!
        media_attachment.download_thumbnail!
        media_attachment.save
      rescue Mastodon::UnexpectedResponseError, HTTP::TimeoutError, HTTP::ConnectionError, OpenSSL::SSL::SSLError
        RedownloadMediaWorker.perform_in(rand(30..600).seconds, media_attachment.id)
      rescue Seahorse::Client::NetworkingError => e
        Rails.logger.warn "Error storing media attachment: #{e}"
        RedownloadMediaWorker.perform_async(media_attachment.id)
      end
    end

    media_attachments
  rescue Addressable::URI::InvalidURIError => e
    Rails.logger.debug { "Invalid URL in attachment: #{e}" }
    media_attachments
  end

  def process_poll
    poll_parser = ActivityPub::Parser::PollParser.new(@object)

    return unless poll_parser.valid?

    @account.polls.new(
      multiple: poll_parser.multiple,
      expires_at: poll_parser.expires_at,
      options: poll_parser.options,
      cached_tallies: poll_parser.cached_tallies,
      voters_count: poll_parser.voters_count
    )
  end

  def poll_vote?
    return false if replied_to_status.nil? || replied_to_status.preloadable_poll.nil? || !replied_to_status.local? || !replied_to_status.preloadable_poll.options.include?(@object['name'])

    return true unless check_invalid_reaction_for_ng_rule! @account, uri: @json['id'], reaction_type: 'vote', recipient: replied_to_status.account, target_status: replied_to_status

    poll_vote! unless replied_to_status.preloadable_poll.expired?

    true
  end

  def poll_vote!
    poll = replied_to_status.preloadable_poll
    already_voted = true

    with_redis_lock("vote:#{replied_to_status.poll_id}:#{@account.id}") do
      already_voted = poll.votes.exists?(account: @account)
      poll.votes.create!(account: @account, choice: poll.options.index(@object['name']), uri: object_uri)
    end

    increment_voters_count! unless already_voted
    ActivityPub::DistributePollUpdateWorker.perform_in(3.minutes, replied_to_status.id) unless replied_to_status.preloadable_poll.hide_totals?
  end

  def process_pending_status
    with_redis_lock("pending_status:#{@object['id']}") do
      return if PendingStatus.exists?(uri: @object['id'])

      fetch_account = as_array(@object['tag'])
                      .filter_map { |tag| equals_or_includes?(tag['type'], 'Mention') && tag['href'] && ActivityPub::TagManager.instance.local_uri?(tag['href']) && ActivityPub::TagManager.instance.uri_to_resource(tag['href'], Account) }
                      .first
      fetch_account ||= (audience_to + audience_cc).filter_map { |uri| ActivityPub::TagManager.instance.local_uri?(uri) && ActivityPub::TagManager.instance.uri_to_resource(uri, Account) }.first
      fetch_account ||= Account.representative

      PendingStatus.create!(account: @account, uri: @object['id'], fetch_account: fetch_account)
    end
  end

  def resolve_thread(status)
    return unless status.reply? && status.thread.nil? && Request.valid_url?(in_reply_to_uri)

    ThreadResolveWorker.perform_async(status.id, in_reply_to_uri, { 'request_id' => @options[:request_id] })
  end

  def resolve_unresolved_mentions(status)
    @unresolved_mentions.uniq.each do |uri|
      MentionResolveWorker.perform_in(rand(30...600).seconds, status.id, uri, { 'request_id' => @options[:request_id] })
    end
  end

  def fetch_replies(status)
    collection = @object['replies']
    return if collection.blank?

    replies = ActivityPub::FetchRepliesService.new.call(status, collection, allow_synchronous_requests: false, request_id: @options[:request_id])
    return unless replies.nil?

    uri = value_or_id(collection)
    ActivityPub::FetchRepliesWorker.perform_async(status.id, uri, { 'request_id' => @options[:request_id] }) unless uri.nil?
  rescue => e
    Rails.logger.warn "Error fetching replies: #{e}"
  end

  def conversation_from_activity
    conversation_from_context(@object['context']) || conversation_from_uri(@object['conversation'])
  end

  def conversation_from_uri(uri)
    return nil if uri.nil?
    return Conversation.find_by(id: OStatus::TagManager.instance.unique_tag_to_local_id(uri, 'Conversation')) if OStatus::TagManager.instance.local_id?(uri)

    begin
      Conversation.find_or_create_by!(uri: uri)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      retry
    end
  end

  def conversation_from_context(uri)
    return nil if uri.nil? || (!uri.start_with?('https://') && !uri.start_with?('http://'))
    return Conversation.find_by(id: ActivityPub::TagManager.instance.uri_to_local_id(uri)) if ActivityPub::TagManager.instance.local_uri?(uri)

    begin
      conversation = Conversation.find_or_create_by!(uri: uri)

      json = fetch_resource_without_id_validation(uri, account_representative)
      return conversation if json.nil? || json['type'] != 'Group'
      return conversation if json['inbox'].blank? || json['inbox'] == conversation.inbox_url

      conversation.update!(inbox_url: json['inbox'])
      conversation
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      retry
    rescue Mastodon::UnexpectedResponseError
      Conversation.find_or_create_by!(uri: uri)
    end
  end

  def replied_to_status
    return @replied_to_status if defined?(@replied_to_status)

    if in_reply_to_uri.blank?
      @replied_to_status = nil
    else
      @replied_to_status   = status_from_uri(in_reply_to_uri)
      @replied_to_status ||= status_from_uri(@object['inReplyToAtomUri']) if @object['inReplyToAtomUri'].present?
      @replied_to_status
    end
  end

  def in_reply_to_uri
    value_or_id(@object['inReplyTo'])
  end

  def converted_text
    [formatted_title, @status_parser.spoiler_text.presence, formatted_url].compact.join("\n\n")
  end

  def formatted_title
    "<h2>#{@status_parser.title}</h2>" if @status_parser.title.present?
  end

  def formatted_url
    linkify(@status_parser.url || @status_parser.uri)
  end

  def unsupported_media_type?(mime_type)
    mime_type.present? && !MediaAttachment.supported_mime_types.include?(mime_type)
  end

  def skip_download?
    return @skip_download if defined?(@skip_download)

    @skip_download ||= DomainBlock.reject_media?(@account.domain)
  end

  def reply_to_local?
    !replied_to_status.nil? && replied_to_status.account.local?
  end

  def mention_to_local_stranger?
    mentioned_accounts.any? { |account| account.local? && !account.following?(@account) }
  end

  def mentioned_accounts
    return @mentioned_accounts if defined?(@mentioned_accounts)

    @mentioned_accounts = (accounts_in_audience + [replied_to_status&.account] + (@mentions&.map(&:account) || [])).compact.uniq
  end

  def reference_to_local_account?
    local_referred_accounts.any?
  end

  def reference_to_local_stranger?
    local_referred_accounts.any? { |account| !account.following?(@account) }
  end

  def reject_reply_exclude_followers?
    @reject_reply_exclude_followers ||= DomainBlock.reject_reply_exclude_followers?(@account.domain)
  end

  def local_following_sender?
    ::Follow.exists?(account: Account.local, target_account: @account)
  end

  def ignore_hashtags?
    return @ignore_hashtags if defined?(@ignore_hashtags)

    @ignore_hashtags ||= DomainBlock.reject_hashtag?(@account.domain)
  end

  def related_to_local_activity?
    fetch? || followed_by_local_accounts? || requested_through_relay? ||
      responds_to_followed_account? || addresses_local_accounts? || quote_local? || free_friend_domain?
  end

  def responds_to_followed_account?
    !replied_to_status.nil? && (replied_to_status.account.local? || replied_to_status.account.passive_relationships.exists?)
  end

  def addresses_local_accounts?
    return true if @options[:delivered_to_account_id]

    local_usernames = (audience_to + audience_cc).uniq.select { |uri| ActivityPub::TagManager.instance.local_uri?(uri) }.map { |uri| ActivityPub::TagManager.instance.uri_to_local_id(uri, :username) }

    return false if local_usernames.empty?

    Account.local.exists?(username: local_usernames)
  end

  def tombstone_exists?
    Tombstone.exists?(uri: object_uri)
  end

  def forward_for_reply
    return unless @status.distributable? && @json['signature'].present? && reply_to_local?

    ActivityPub::RawDistributionWorker.perform_async(Oj.dump(@json), replied_to_status.account_id, [@account.preferred_inbox_url])
  end

  def process_conversation!
    return unless @status.conversation.present? && @status.conversation.local?

    ProcessConversationService.new.call(@status)

    return if @json['signature'].blank?

    ActivityPub::ForwardConversationWorker.perform_async(Oj.dump(@json), @status.id, false)
  end

  def increment_voters_count!
    poll = replied_to_status.preloadable_poll

    unless poll.voters_count.nil?
      poll.voters_count = poll.voters_count + 1
      poll.save
    end
  rescue ActiveRecord::StaleObjectError
    poll.reload
    retry
  end

  def reference_uris
    return @reference_uris if defined?(@reference_uris)

    @reference_uris = @object['references'].nil? ? [] : (ActivityPub::FetchReferencesService.new.call(@account, @object['references']) || []).uniq
    @reference_uris += ProcessReferencesService.extract_uris(@object['content'] || '', remote: true)
  end

  def local_referred_accounts
    return @local_referred_accounts if defined?(@local_referred_accounts)

    local_referred_statuses = reference_uris.filter_map do |uri|
      ActivityPub::TagManager.instance.local_uri?(uri) && ActivityPub::TagManager.instance.uri_to_resource(uri, Status)
    end.compact

    @local_referred_accounts = local_referred_statuses.map(&:account)
  end

  def process_references!
    ProcessReferencesService.call_service_without_error(@status, [], reference_uris, [quote].compact)
  end

  def quote_local?
    url = quote

    if url.present?
      ActivityPub::TagManager.instance.uri_to_resource(url, Status)&.local?
    else
      false
    end
  end

  def free_friend_domain?
    FriendDomain.free_receivings.exists?(domain: @account.domain)
  end

  def friend_domain?
    FriendDomain.enabled.find_by(domain: @account.domain)&.accepted?
  end

  def quote
    @quote ||= quote_from_tags || @object['quote'] || @object['quoteUrl'] || @object['quoteURL'] || @object['_misskey_quote']
  end

  LINK_MEDIA_TYPES = ['application/activity+json', 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'].freeze

  def quote_from_tags
    return @quote_from_tags if defined?(@quote_from_tags)

    hit_tag = as_array(@object['tag']).detect do |tag|
      equals_or_includes?(tag['type'], 'Link') && LINK_MEDIA_TYPES.include?(tag['mediaType']) && tag['href'].present?
    end
    @quote_from_tags = hit_tag && hit_tag['href']
  end
end
