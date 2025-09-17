# frozen_string_literal: true

class ActivityPub::ContextPresenter < ActiveModelSerializers::Model
  attributes :id, :type, :attributed_to, :first, :object_type, :inbox

  class << self
    include RoutingHelper

    def from_conversation(conversation)
      new.tap do |presenter|
        presenter.id = ActivityPub::TagManager.instance.uri_for(conversation)
        presenter.attributed_to = ActivityPub::TagManager.instance.uri_for(conversation.parent_account) if conversation.parent_account.present?
        presenter.inbox = inbox(conversation)
      end
    end

    # Fedibird compat
    def inbox(conversation)
      return '' if conversation.ancestor_status.nil?

      account_inbox_url(conversation.ancestor_status.account)
    end
  end
end
