# frozen_string_literal: true

# == Schema Information
#
# Table name: custom_emojis
#
#  id                           :bigint(8)        not null, primary key
#  shortcode                    :string           default(""), not null
#  domain                       :string
#  image_file_name              :string
#  image_content_type           :string
#  image_updated_at             :datetime
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  disabled                     :boolean          default(FALSE), not null
#  uri                          :string
#  image_remote_url             :string
#  visible_in_picker            :boolean          default(TRUE), not null
#  category_id                  :bigint(8)
#  image_storage_schema_version :integer
#  image_width                  :integer
#  image_height                 :integer
#  aliases                      :jsonb
#  is_sensitive                 :boolean          default(FALSE), not null
#  license                      :string
#  image_file_size              :integer
#

class CustomEmoji < ApplicationRecord
  include Attachmentable

  LIMIT = 512.kilobytes
  MINIMUM_SHORTCODE_SIZE = 2

  SHORTCODE_RE_FRAGMENT = '[a-zA-Z0-9_]{2,}'

  SCAN_RE = /:(#{SHORTCODE_RE_FRAGMENT}):/x
  SHORTCODE_ONLY_RE = /\A#{SHORTCODE_RE_FRAGMENT}\z/

  IMAGE_MIME_TYPES = %w(image/png image/gif image/webp image/jpeg).freeze

  belongs_to :category, class_name: 'CustomEmojiCategory', optional: true
  has_one :local_counterpart, -> { where(domain: nil) }, class_name: 'CustomEmoji', primary_key: :shortcode, foreign_key: :shortcode, inverse_of: false, dependent: nil
  has_many :emoji_reactions, inverse_of: :custom_emoji, dependent: :destroy

  has_attached_file :image, styles: { static: { format: 'png', convert_options: '-coalesce +profile "!icc,*" +set date:modify +set date:create +set date:timestamp', file_geometry_parser: FastGeometryParser } }, validate_media_type: false, processors: [:lazy_thumbnail]

  normalizes :domain, with: ->(domain) { domain.downcase }

  validates_attachment :image, content_type: { content_type: IMAGE_MIME_TYPES }, presence: true, size: { less_than: LIMIT }
  validates :shortcode, uniqueness: { scope: :domain }, format: { with: SHORTCODE_ONLY_RE }, length: { minimum: MINIMUM_SHORTCODE_SIZE }

  scope :local, -> { where(domain: nil) }
  scope :remote, -> { where.not(domain: nil) }
  scope :enabled, -> { where(disabled: false) }
  scope :alphabetic, -> { order(domain: :asc, shortcode: :asc) }
  scope :by_domain_and_subdomains, ->(domain) { where(domain: domain).or(where(arel_table[:domain].matches("%.#{domain}"))) }
  scope :listed, -> { local.enabled.where(visible_in_picker: true) }

  remotable_attachment :image, LIMIT

  after_commit :remove_entity_cache

  after_post_process :set_post_size

  def local?
    domain.nil?
  end

  def object_type
    :emoji
  end

  def copy!
    copy = self.class.find_or_initialize_by(
      domain: nil,
      shortcode: shortcode
    )
    copy.aliases = (aliases || []).compact_blank
    copy.license = license
    copy.is_sensitive = is_sensitive
    copy.image = image
    copy.tap(&:save!)
  end

  def to_log_human_identifier
    shortcode
  end

  def update_size
    size(Rails.configuration.x.use_s3 ? image.url : image.path)
  end

  def aliases_raw
    return '' if aliases.nil? || aliases.blank?

    aliases.join(',')
  end

  def aliases_raw=(raw)
    aliases = raw.split(',').compact_blank.uniq
    self[:aliases] = aliases
  end

  class << self
    def from_text(text, domain = nil)
      return [] if text.blank?

      shortcodes = text.scan(SCAN_RE).map(&:first).uniq

      return [] if shortcodes.empty?

      EntityCache.instance.emoji(shortcodes, domain)
    end

    def search(shortcode)
      where(arel_table[:shortcode].matches("%#{sanitize_sql_like(shortcode)}%"))
    end
  end

  private

  def remove_entity_cache
    Rails.cache.delete(EntityCache.instance.to_key(:emoji, shortcode, domain))
  end

  def set_post_size
    image.queued_for_write.each do |style, file|
      size(file.path) if style == :original
    end
  end

  def size(path)
    image_size = FastImage.size(path)
    self.image_width = image_size[0]
    self.image_height = image_size[1]
  end
end
