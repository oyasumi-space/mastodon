# frozen_string_literal: true

class REST::AccountSerializer < ActiveModel::Serializer
  include RoutingHelper
  include FormattingHelper

  # Please update `app/javascript/mastodon/api_types/accounts.ts` when making changes to the attributes

  attributes :id, :username, :acct, :display_name, :locked, :bot, :discoverable, :indexable, :group, :created_at,
             :note, :url, :uri, :avatar, :avatar_static, :header, :header_static, :subscribable,
             :followers_count, :following_count, :statuses_count, :last_status_at, :hide_collections, :other_settings, :noindex,
             :server_features

  has_one :moved_to_account, key: :moved, serializer: REST::AccountSerializer, if: :moved_and_not_nested?

  has_many :emojis, serializer: REST::CustomEmojiSlimSerializer

  attribute :suspended, if: :suspended?
  attribute :silenced, key: :limited, if: :silenced?

  attribute :memorial, if: :memorial?

  class AccountDecorator < SimpleDelegator
    def self.model_name
      Account.model_name
    end

    def moved?
      false
    end
  end

  class RoleSerializer < ActiveModel::Serializer
    attributes :id, :name, :color

    def id
      object.id.to_s
    end
  end

  has_many :roles, serializer: RoleSerializer, if: :local?

  class FieldSerializer < ActiveModel::Serializer
    include FormattingHelper

    attributes :name, :value, :verified_at

    def value
      account_field_value_format(object)
    end
  end

  has_many :fields

  def id
    object.id.to_s
  end

  def acct
    object.pretty_acct
  end

  def note
    object.unavailable? ? '' : account_bio_format(object)
  end

  def url
    ActivityPub::TagManager.instance.url_for(object)
  end

  def uri
    ActivityPub::TagManager.instance.uri_for(object)
  end

  def avatar
    full_asset_url(object.unavailable? ? object.avatar.default_url : object.avatar_original_url)
  end

  def avatar_static
    full_asset_url(object.unavailable? ? object.avatar.default_url : object.avatar_static_url)
  end

  def header
    full_asset_url(object.unavailable? ? object.header.default_url : object.header_original_url)
  end

  def header_static
    full_asset_url(object.unavailable? ? object.header.default_url : object.header_static_url)
  end

  def created_at
    object.created_at.midnight.as_json
  end

  def last_status_at
    object.last_status_at&.to_date&.iso8601
  end

  def display_name
    object.unavailable? ? '' : object.display_name
  end

  def locked
    object.unavailable? ? false : object.locked
  end

  def bot
    object.unavailable? ? false : object.bot
  end

  def discoverable
    object.unavailable? ? false : object.discoverable
  end

  def subscribable
    object.all_subscribable?
  end

  def indexable
    object.unavailable? ? false : object.indexable
  end

  def server_features
    InstanceInfo.available_features(object.domain)
  end

  def moved_to_account
    object.unavailable? ? nil : AccountDecorator.new(object.moved_to_account)
  end

  def emojis
    object.unavailable? ? [] : object.emojis
  end

  def fields
    object.unavailable? ? [] : object.fields
  end

  def suspended
    object.unavailable?
  end

  def silenced
    object.silenced?
  end

  def memorial
    object.memorial?
  end

  def roles
    if object.unavailable? || object.user.nil?
      []
    else
      [object.user.role].compact.filter(&:highlighted?)
    end
  end

  def noindex
    object.noindex?
  end

  delegate :suspended?, :silenced?, :local?, :memorial?, to: :object

  def moved_and_not_nested?
    object.moved?
  end

  def statuses_count
    object.public_statuses_count
  end

  def followers_count
    object.public_followers_count
  end

  def following_count
    object.public_following_count
  end

  def other_settings
    object.suspended? ? {} : object.public_settings_for_local
  end
end
