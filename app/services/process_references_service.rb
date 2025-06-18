# frozen_string_literal: true

class ProcessReferencesService < BaseService
  include Payloadable
  include FormattingHelper
  include Redisable
  include Lockable

  DOMAIN = ENV['WEB_DOMAIN'] || ENV.fetch('LOCAL_DOMAIN', nil)
  REFURL_EXP = /(RT|QT|BT|RN|RE)((:|;)?\s+|:|;)(#{URI::DEFAULT_PARSER.make_regexp(%w(http https))})/
  QUOTEURL_EXP = /(QT|RN|RE)((:|;)?\s+|:|;)(#{URI::DEFAULT_PARSER.make_regexp(%w(http https))})/
  MAX_REFERENCES = 5

  def call(status, reference_parameters, urls: nil, fetch_remote: true, no_fetch_urls: nil)
    @status = status
    @reference_parameters = reference_parameters || []
    @urls = urls || []
    @no_fetch_urls = no_fetch_urls || []
    @fetch_remote = fetch_remote
    @again = false

    @attributes = {}

    with_redis_lock("process_status_refs:#{@status.id}") do
      @references_count = @status.reference_objects.count
      build_references_diff

      if @added_items.present? || @removed_items.present? || @changed_items.present?
        StatusReference.transaction do
          remove_old_references
          add_references
          change_reference_attributes

          @status.save!
        end

        create_notifications!
      end
    end

    launch_worker if @again
  end

  def self.need_process?(status, reference_parameters, urls, quote: nil)
    reference_parameters.any? || [urls, quote].flatten.compact.any? || FormattingHelper.extract_status_plain_text(status).scan(REFURL_EXP).pluck(3).uniq.any?
  end

  def self.extract_uris(text, remote: false)
    return text.scan(REFURL_EXP).pluck(3) unless remote

    PlainTextFormatter.new(text, false).to_s.scan(REFURL_EXP).pluck(3)
  end

  def self.extract_quote(text)
    text.scan(QUOTEURL_EXP).pick(3)
  end

  def self.call_service(status, reference_parameters, urls, quote: nil)
    return unless need_process?(status, reference_parameters, urls, quote: quote)

    ProcessReferencesService.new.call(status, reference_parameters || [], urls: [urls, quote].flatten.compact || [], fetch_remote: false)
  end

  def self.call_service_without_error(status, reference_parameters, urls, quote: nil)
    return unless need_process?(status, reference_parameters, urls, quote: quote)

    begin
      ProcessReferencesService.new.call(status, reference_parameters || [], urls: [urls, quote].flatten.compact)
    rescue
      true
    end
  end

  private

  def build_old_references
    @status.reference_objects.pluck(:target_status_id, :attribute_type).to_h
  end

  def build_new_references
    scan_text_and_quotes.tap do |status_id_to_attributes|
      @reference_parameters.each do |status_id|
        id_num = status_id.to_i
        status_id_to_attributes[id_num] = 'BT' unless id_num.positive? && status_id_to_attributes.key?(id_num)
      end
    end
  end

  def build_references_diff
    olds = build_old_references
    news = build_new_references

    @changed_items = {}
    @added_items = {}
    @removed_items = {}

    news.each_key do |status_id|
      exist_attribute = olds[status_id]

      @added_items[status_id] = news[status_id] if exist_attribute.nil?
      @changed_items[status_id] = news[status_id] if olds.key?(status_id) && exist_attribute != news[status_id]
    end

    olds.each_key do |status_id|
      new_attribute = news[status_id]

      @removed_items[status_id] = olds[status_id] if new_attribute.nil?
    end
  end

  def scan_text_and_quotes
    text = extract_status_plain_text(@status)
    url_to_attributes = @urls.index_with('BT')
                             .merge(text.scan(REFURL_EXP).to_h { |result| [result[3], result[0]] })

    url_to_statuses = fetch_statuses(url_to_attributes.keys.uniq)

    @again = true if !@fetch_remote && url_to_statuses.values.any?(&:nil?)

    url_to_statuses.keys.to_h do |url|
      attribute = url_to_attributes[url] || 'BT'
      status = url_to_statuses[url]

      if status.present?
        quote_attribute?(attribute)

        [status.id, attribute]
      else
        [url, attribute]
      end
    end
  end

  def quote_attribute?(attribute)
    %w(QT RE).include?(attribute)
  end

  def fetch_statuses(urls)
    urls.to_h do |url|
      status = url_to_status(url)
      @no_fetch_urls << url if !@fetch_remote && status.present?
      [url, status]
    end
  end

  def url_to_status(url)
    status   = ActivityPub::TagManager.instance.uri_to_resource(url, Status, url: true)
    status ||= ResolveURLService.new.call(url, on_behalf_of: @status.account) unless bad_url_to_fetch?(url)
    referrable?(status) ? status : nil
  end

  def bad_url_to_fetch?(url)
    uri = Addressable::URI.parse(url).normalize

    !@fetch_remote || @no_fetch_urls.include?(url) || uri.host.blank? || Setting.stop_fetch_activity_domains&.include?(uri.host)
  end

  def referrable?(target_status)
    return false if target_status.nil?
    return @referrable if defined?(@referrable)

    @referrable = StatusPolicy.new(@status.account, target_status).show?
  end

  def add_references
    return if @added_items.empty?

    @added_objects = []

    statuses = Status.where(id: @added_items.keys).to_a
    @added_items.each_key do |status_id|
      status = statuses.find { |s| s.id == status_id }
      next if status.blank?

      attribute_type = @added_items[status_id]
      @added_objects << @status.reference_objects.new(target_status: status, attribute_type: attribute_type)

      status.increment_count!(:status_referred_by_count)
      @references_count += 1

      break if @references_count >= MAX_REFERENCES
    end
  end

  def create_notifications!
    return if @added_objects.blank?

    local_reference_objects = @added_objects.filter { |ref| ref.target_status.account.local? && StatusPolicy.new(ref.target_status.account, ref.status).show? }
    return if local_reference_objects.empty?

    LocalNotificationWorker.push_bulk(local_reference_objects) do |ref|
      [ref.target_status.account_id, ref.id, 'StatusReference', 'status_reference']
    end
  end

  def remove_old_references
    return if @removed_items.empty?

    @removed_objects = []

    @status.reference_objects.where(target_status: @removed_items.keys).destroy_all

    statuses = Status.where(id: @added_items.keys).to_a
    @removed_items.each_key do |status_id|
      status = statuses.find { |s| s.id == status_id }
      next if status.blank?

      status.decrement_count!(:status_referred_by_count)
      @references_count -= 1
    end
  end

  def change_reference_attributes
    return if @changed_items.empty?

    @changed_objects = []

    @status.reference_objects.where(target_status: @changed_items.keys).find_each do |ref|
      attribute_type = @changed_items[ref.target_status_id]

      ref.update!(attribute_type: attribute_type)
    end
  end

  def launch_worker
    ProcessReferencesWorker.perform_async(@status.id, @reference_parameters, @urls, @no_fetch_urls)
  end
end
