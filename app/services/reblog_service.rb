# frozen_string_literal: true

class ReblogService < BaseService
  include Authorization
  include Payloadable
  include NgRuleHelper

  # Reblog a status and notify its remote author
  # @param [Account] account Account to reblog from
  # @param [Status] reblogged_status Status to be reblogged
  # @param [Hash] options
  # @option [String]  :visibility
  # @option [Boolean] :with_rate_limit
  # @return [Status]
  def call(account, reblogged_status, options = {})
    reblogged_status = reblogged_status.reblog if reblogged_status.reblog?

    authorize_with account, reblogged_status, :reblog?

    raise Mastodon::ValidationError, I18n.t('statuses.violate_rules') unless check_invalid_reaction_for_ng_rule! account, reaction_type: 'reblog', recipient: reblogged_status.account, target_status: reblogged_status

    reblog = account.statuses.find_by(reblog: reblogged_status)

    return reblog unless reblog.nil?

    visibility = if reblogged_status.hidden?
                   reblogged_status.visibility
                 else
                   options[:visibility] ||
                     (account.user&.setting_default_reblog_privacy == 'unset' ? account.user&.setting_default_privacy : account.user&.setting_default_reblog_privacy)
                 end.to_s

    visibility = 'public_unlisted' if !Setting.enable_public_visibility && visibility == 'public'
    visibility = 'unlisted' if !Setting.enable_public_unlisted_visibility && visibility == 'public_unlisted'

    reblog = account.statuses.create!(reblog: reblogged_status, text: '', visibility: visibility, rate_limit: options[:with_rate_limit])

    Trends.register!(reblog)
    DistributionWorker.perform_async(reblog.id)
    ActivityPub::DistributionWorker.perform_async(reblog.id)

    create_notification(reblog)
    increment_statistics

    reblog
  end

  private

  def create_notification(reblog)
    reblogged_status = reblog.reblog

    LocalNotificationWorker.perform_async(reblogged_status.account_id, reblog.id, reblog.class.name, 'reblog') if reblogged_status.account.local?
  end

  def increment_statistics
    ActivityTracker.increment('activity:interactions')
  end

  def build_json(reblog)
    Oj.dump(serialize_payload(ActivityPub::ActivityPresenter.from_status(reblog), ActivityPub::ActivitySerializer, signer: reblog.account))
  end
end
