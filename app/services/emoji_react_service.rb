# frozen_string_literal: true

class EmojiReactService < BaseService
  include Authorization
  include Payloadable
  include Redisable
  include Lockable
  include NgRuleHelper

  # React a status with emoji and notify remote user
  # @param [Account] account
  # @param [Status] status
  # @param [string] name
  # @return [Favourite]
  def call(account, status, name)
    status = status.reblog if status.reblog? && !status.reblog.nil?
    authorize_with account, status, :emoji_reaction?
    @status = status

    raise Mastodon::ValidationError, I18n.t('reactions.errors.banned') if account.silenced? && !status.account.following?(account)

    shortcode, domain = name.split('@')
    domain = nil if TagManager.instance.local_domain?(domain)

    raise Mastodon::ValidationError, I18n.t('statuses.violate_rules') unless check_invalid_reaction_for_ng_rule! account, reaction_type: 'emoji_reaction', emoji_reaction_name: shortcode, emoji_reaction_origin_domain: domain, recipient: status.account, target_status: status

    with_redis_lock("emoji_reaction:#{status.id}") do
      custom_emoji = CustomEmoji.find_by(shortcode: shortcode, domain: domain)
      return if domain.present? && !EmojiReaction.exists?(status: status, custom_emoji: custom_emoji)

      @emoji_reaction = EmojiReaction.find_by(account: account, status: status, name: shortcode, custom_emoji: custom_emoji)
      raise Mastodon::ValidationError, I18n.t('reactions.errors.duplication') unless @emoji_reaction.nil?

      @emoji_reaction = EmojiReaction.create!(account: account, status: status, name: shortcode, custom_emoji: custom_emoji)

      status.touch
    end

    raise Mastodon::ValidationError, I18n.t('reactions.errors.duplication') if @emoji_reaction.nil?

    Trends.statuses.register(status)

    create_notification
    notify_to_followers
    increment_statistics
    write_stream! if Setting.streaming_local_emoji_reaction

    @emoji_reaction
  end

  private

  def create_notification
    status = @emoji_reaction.status
    return unless status.account.local?
    return unless status.account.user&.setting_enable_emoji_reaction

    LocalNotificationWorker.perform_async(status.account_id, @emoji_reaction.id, 'EmojiReaction', 'reaction') if status.account.user&.setting_emoji_reaction_streaming_notify_impl2
    LocalNotificationWorker.perform_async(status.account_id, @emoji_reaction.id, 'EmojiReaction', 'emoji_reaction')
  end

  def notify_to_followers
    ActivityPub::EmojiReactionDistributionWorker.perform_async(@emoji_reaction.id)
  end

  def write_stream!
    emoji_group = @emoji_reaction.status.emoji_reactions_grouped_by_name(nil, force: true)
                                 .find { |reaction_group| reaction_group['name'] == @emoji_reaction.name && (!reaction_group.key?(:domain) || reaction_group['domain'] == @emoji_reaction.custom_emoji&.domain) }
    emoji_group['status_id'] = @emoji_reaction.status_id.to_s
    DeliveryEmojiReactionWorker.perform_async(render_emoji_reaction(emoji_group), @emoji_reaction.status_id, @emoji_reaction.account_id)
  end

  def increment_statistics
    ActivityTracker.increment('activity:interactions')
  end

  def payload
    @payload = Oj.dump(serialize_payload(@emoji_reaction, ActivityPub::EmojiReactionSerializer, signer: @emoji_reaction.account))
  end

  def render_emoji_reaction(emoji_group)
    # @rendered_emoji_reaction ||= InlineRenderer.render(HashObject.new(emoji_group), nil, :emoji_reaction)
    @render_emoji_reaction ||= Oj.dump(event: :emoji_reaction, payload: emoji_group.to_json)
  end
end
