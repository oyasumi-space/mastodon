# frozen_string_literal: true

class REST::NotificationSerializer < ActiveModel::Serializer
  attributes :id, :type, :created_at

  belongs_to :from_account, key: :account, serializer: REST::AccountSerializer
  belongs_to :target_status, key: :status, if: :status_type?, serializer: REST::StatusSerializer
  belongs_to :report, if: :report_type?, serializer: REST::ReportSerializer
  belongs_to :emoji_reaction, if: :emoji_reaction_type?, serializer: REST::NotifyEmojiReactionSerializer
  belongs_to :list, if: :list_status_type?, serializer: REST::ListSerializer
  belongs_to :account_relationship_severance_event, key: :event, if: :relationship_severance_event?, serializer: REST::AccountRelationshipSeveranceEventSerializer
  belongs_to :account_warning, key: :moderation_warning, if: :moderation_warning_event?, serializer: REST::AccountWarningSerializer

  def id
    object.id.to_s
  end

  def status_type?
    [:favourite, :emoji_reaction, :reaction, :reblog, :status_reference, :status, :list_status, :mention, :poll, :update].include?(object.type)
  end

  def report_type?
    object.type == :'admin.report'
  end

  def emoji_reaction_type?
    object.type == :emoji_reaction
  end

  def list_status_type?
    object.type == :list_status
  end

  def list
    object.list_status.list
  end

  def relationship_severance_event?
    object.type == :severed_relationships
  end

  def moderation_warning_event?
    object.type == :moderation_warning
  end
end
