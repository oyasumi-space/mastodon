# frozen_string_literal: true

class InitialStateSerializer < ActiveModel::Serializer
  include RoutingHelper
  include DtlHelper
  include RegistrationLimitationHelper

  attributes :meta, :compose, :accounts,
             :media_attachments, :settings,
             :languages

  attribute :critical_updates_pending, if: -> { object&.role&.can?(:view_devops) && SoftwareUpdate.check_enabled? }

  has_one :push_subscription, serializer: REST::WebPushSubscriptionSerializer
  has_one :role, serializer: REST::RoleSerializer

  def meta
    store = default_meta_store

    if object.current_account
      store[:me]                = object.current_account.id.to_s
      store[:boost_modal]       = object_account_user.setting_boost_modal
      store[:delete_modal]      = object_account_user.setting_delete_modal
      store[:auto_play_gif]     = object_account_user.setting_auto_play_gif
      store[:display_media]     = object_account_user.setting_display_media
      store[:expand_spoilers] = object_account_user.setting_expand_spoilers
      store[:enable_emoji_reaction] = object_account_user.setting_enable_emoji_reaction && Setting.enable_emoji_reaction
      store[:enable_dtl_menu]   = object_account_user.setting_enable_dtl_menu
      store[:reduce_motion]     = object_account_user.setting_reduce_motion
      store[:disable_swiping]   = object_account_user.setting_disable_swiping
      store[:disable_hover_cards] = object_account_user.setting_disable_hover_cards
      store[:advanced_layout]   = object_account_user.setting_advanced_layout
      store[:use_blurhash]      = object_account_user.setting_use_blurhash
      store[:use_pending_items] = object_account_user.setting_use_pending_items
      store[:show_trends]       = Setting.trends && object_account_user.setting_trends
      store[:bookmark_category_needed] = object_account_user.setting_bookmark_category_needed
      store[:simple_timeline_menu] = object_account_user.setting_simple_timeline_menu
      store[:boost_menu] = object_account_user.setting_boost_menu
      store[:hide_items] = [
        object_account_user.setting_hide_favourite_menu ? 'favourite_menu' : nil,
        object_account_user.setting_hide_recent_emojis ? 'recent_emojis' : nil,
        object_account_user.setting_hide_blocking_quote ? 'blocking_quote' : nil,
        object_account_user.setting_hide_emoji_reaction_unavailable_server ? 'emoji_reaction_unavailable_server' : nil,
        object_account_user.setting_hide_quote_unavailable_server ? 'quote_unavailable_server' : nil,
        object_account_user.setting_hide_status_reference_unavailable_server ? 'status_reference_unavailable_server' : nil,
        object_account_user.setting_hide_emoji_reaction_count ? 'emoji_reaction_count' : nil,
        object_account_user.setting_show_emoji_reaction_on_timeline ? nil : 'emoji_reaction_on_timeline',
        object_account_user.setting_show_quote_in_home ? nil : 'quote_in_home',
        object_account_user.setting_show_quote_in_public ? nil : 'quote_in_public',
        object_account_user.setting_show_relationships ? nil : 'relationships',
      ].compact
      store[:enabled_visibilities] = enabled_visibilities
      store[:featured_tags] = object.current_account.featured_tags.pluck(:name)
    else
      store[:auto_play_gif] = Setting.auto_play_gif
      store[:display_media] = Setting.display_media
      store[:reduce_motion] = Setting.reduce_motion
      store[:use_blurhash]  = Setting.use_blurhash
      store[:enable_emoji_reaction] = Setting.enable_emoji_reaction
      store[:hide_items] = [
        Setting.enable_emoji_reaction ? nil : 'emoji_reaction_on_timeline',
      ].compact
    end

    store[:disabled_account_id] = object.disabled_account.id.to_s if object.disabled_account
    store[:moved_to_account_id] = object.moved_to_account.id.to_s if object.moved_to_account

    store[:owner] = object.owner&.id&.to_s if Rails.configuration.x.single_user_mode

    store
  end

  def compose
    store = {}

    if object.current_account
      store[:me]                    = object.current_account.id.to_s
      store[:default_privacy]       = object.visibility || object_account_user.setting_default_privacy
      store[:stay_privacy]          = object_account_user.setting_stay_privacy
      store[:default_searchability] = object.searchability || object_account_user.setting_default_searchability
      store[:default_sensitive]     = object_account_user.setting_default_sensitive
      store[:default_language]      = object_account_user.preferred_posting_language
    end

    store[:text] = object.text if object.text

    store
  end

  def accounts
    store = {}

    ActiveRecord::Associations::Preloader.new(
      records: [object.current_account, object.admin, object.owner, object.disabled_account, object.moved_to_account].compact,
      associations: [:account_stat, { user: :role, moved_to_account: [:account_stat, { user: :role }] }]
    ).call

    store[object.current_account.id.to_s]  = serialized_account(object.current_account) if object.current_account
    store[object.admin.id.to_s]            = serialized_account(object.admin) if object.admin
    store[object.owner.id.to_s]            = serialized_account(object.owner) if object.owner
    store[object.disabled_account.id.to_s] = serialized_account(object.disabled_account) if object.disabled_account
    store[object.moved_to_account.id.to_s] = serialized_account(object.moved_to_account) if object.moved_to_account

    store
  end

  def media_attachments
    { accept_content_types: MediaAttachment.supported_file_extensions + MediaAttachment.supported_mime_types }
  end

  def languages
    LanguagesHelper::SUPPORTED_LOCALES.map { |(key, value)| [key, value[0], value[1]] }
  end

  def enabled_visibilities
    vs = object_account_user.setting_enabled_visibilities
    vs -= %w(public_unlisted) unless Setting.enable_public_unlisted_visibility
    vs -= %w(public) unless Setting.enable_public_visibility
    vs
  end

  private

  def default_meta_store
    {
      access_token: object.token,
      activity_api_enabled: Setting.activity_api_enabled,
      admin: object.admin&.id&.to_s,
      domain: Addressable::IDNA.to_unicode(instance_presenter.domain),
      dtl_tag: dtl_enabled? ? dtl_tag_name : nil,
      enable_local_timeline: Setting.enable_local_timeline,
      limited_federation_mode: Rails.configuration.x.limited_federation_mode,
      locale: I18n.locale,
      mascot: instance_presenter.mascot&.file&.url,
      profile_directory: Setting.profile_directory,
      registrations_open: Setting.registrations_mode != 'none' && !reach_registrations_limit? && !Rails.configuration.x.single_user_mode,
      registrations_reach_limit: Setting.registrations_mode != 'none' && reach_registrations_limit?,
      repository: Mastodon::Version.repository,
      search_enabled: Chewy.enabled?,
      single_user_mode: Rails.configuration.x.single_user_mode,
      source_url: instance_presenter.source_url,
      sso_redirect: sso_redirect,
      status_page_url: Setting.status_page_url,
      streaming_api_base_url: Rails.configuration.x.streaming_api_base_url,
      timeline_preview: Setting.timeline_preview,
      title: instance_presenter.title,
      trends_as_landing_page: Setting.trends_as_landing_page,
      trends_enabled: Setting.trends,
      version: instance_presenter.version,
    }
  end

  def object_account_user
    object.current_account.user
  end

  def serialized_account(account)
    ActiveModelSerializers::SerializableResource.new(account, serializer: REST::AccountSerializer)
  end

  def instance_presenter
    @instance_presenter ||= InstancePresenter.new
  end

  def sso_redirect
    "/auth/auth/#{Devise.omniauth_providers[0]}" if ENV['ONE_CLICK_SSO_LOGIN'] == 'true' && ENV['OMNIAUTH_ONLY'] == 'true' && Devise.omniauth_providers.length == 1
  end
end
