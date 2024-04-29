# frozen_string_literal: true

module HasUserSettings
  extend ActiveSupport::Concern

  included do
    serialize :settings, UserSettingsSerializer
  end

  def settings_attributes=(attributes)
    settings.update(attributes)
  end

  def prefers_noindex?
    settings['noindex']
  end

  def preferred_posting_language
    valid_locale_cascade(settings['default_language'], locale, I18n.locale)
  end

  def setting_auto_play_gif
    settings['web.auto_play']
  end

  def setting_reaction_deck
    settings['reaction_deck']
  end

  def setting_enable_login_privacy
    settings['web.enable_login_privacy']
  end

  def setting_enable_dtl_menu
    settings['web.enable_dtl_menu']
  end

  def setting_bookmark_category_needed
    settings['web.bookmark_category_needed']
  end

  def setting_hide_recent_emojis
    settings['web.hide_recent_emojis']
  end

  def setting_enable_emoji_reaction
    settings['web.enable_emoji_reaction']
  end

  def setting_show_emoji_reaction_on_timeline
    settings['web.show_emoji_reaction_on_timeline']
  end

  def setting_simple_timeline_menu
    settings['web.simple_timeline_menu']
  end

  def setting_default_sensitive
    settings['default_sensitive']
  end

  def setting_public_post_to_unlisted
    settings['public_post_to_unlisted']
  end

  def setting_reject_public_unlisted_subscription
    settings['reject_public_unlisted_subscription']
  end

  def setting_reject_unlisted_subscription
    settings['reject_unlisted_subscription']
  end

  def setting_send_without_domain_blocks
    settings['send_without_domain_blocks']
  end

  def setting_unsafe_limited_distribution
    settings['unsafe_limited_distribution']
  end

  def setting_stop_emoji_reaction_streaming
    settings['stop_emoji_reaction_streaming']
  end

  def setting_emoji_reaction_streaming_notify_impl2
    false
  end

  def setting_emoji_reaction_policy
    settings['emoji_reaction_policy']
  end

  def setting_unfollow_modal
    settings['web.unfollow_modal']
  end

  def setting_boost_modal
    settings['web.reblog_modal']
  end

  def setting_delete_modal
    settings['web.delete_modal']
  end

  def setting_reduce_motion
    settings['web.reduce_motion']
  end

  def setting_system_font_ui
    settings['web.use_system_font']
  end

  def setting_noindex
    settings['noindex']
  end

  def setting_noai
    settings['noai']
  end

  def setting_translatable_private
    settings['translatable_private']
  end

  def setting_single_ref_to_quote
    settings['single_ref_to_quote']
  end

  def setting_dtl_force_with_tag
    settings['dtl_force_with_tag']&.to_sym || :none
  end

  def setting_dtl_force_subscribable
    settings['dtl_force_subscribable']
  end

  def setting_hide_statuses_count
    settings['hide_statuses_count']
  end

  def setting_hide_following_count
    settings['hide_following_count']
  end

  def setting_hide_followers_count
    settings['hide_followers_count']
  end

  def setting_theme
    settings['theme']
  end

  def setting_bio_markdown
    settings['bio_markdown']
  end

  def setting_discoverable_local
    settings['discoverable_local']
  end

  def setting_display_media
    settings['web.display_media']
  end

  def setting_display_media_expand
    settings['web.display_media_expand']
  end

  def setting_expand_spoilers
    settings['web.expand_content_warnings']
  end

  def setting_default_language
    settings['default_language']
  end

  def setting_aggregate_reblogs
    settings['aggregate_reblogs']
  end

  def setting_show_application
    settings['show_application']
  end

  def setting_advanced_layout
    settings['web.advanced_layout']
  end

  def setting_use_blurhash
    settings['web.use_blurhash']
  end

  def setting_use_pending_items
    settings['web.use_pending_items']
  end

  def setting_trends
    settings['web.trends']
  end

  def setting_disable_swiping
    settings['web.disable_swiping']
  end

  def setting_always_send_emails
    settings['always_send_emails']
  end

  def setting_default_privacy
    settings['default_privacy'] || (account.locked? ? 'private' : 'public')
  end

  def setting_stay_privacy
    settings['stay_privacy']
  end

  def setting_default_reblog_privacy
    settings['default_reblog_privacy'] || 'unset'
  end

  def setting_default_searchability
    settings['default_searchability'] || 'direct'
  end

  def setting_default_searchability_of_search
    settings['default_searchability_of_search']
  end

  def setting_use_public_index
    settings['use_public_index']
  end

  def setting_disallow_unlisted_public_searchability
    settings['disallow_unlisted_public_searchability']
  end

  def setting_lock_follow_from_bot
    settings['lock_follow_from_bot']
  end

  def allows_report_emails?
    settings['notification_emails.report']
  end

  def allows_pending_account_emails?
    settings['notification_emails.pending_account']
  end

  def allows_appeal_emails?
    settings['notification_emails.appeal']
  end

  def allows_trends_review_emails?
    settings['notification_emails.trends']
  end

  def aggregates_reblogs?
    settings['aggregate_reblogs']
  end

  def shows_application?
    settings['show_application']
  end

  def show_all_media?
    settings['web.display_media'] == 'show_all'
  end

  def hide_all_media?
    settings['web.display_media'] == 'hide_all'
  end
end
