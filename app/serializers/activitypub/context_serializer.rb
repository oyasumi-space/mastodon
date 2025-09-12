# frozen_string_literal: true

class ActivityPub::ContextSerializer < ActivityPub::Serializer
  attributes :id, :type, :attributed_to, :first, :inbox

  def type
    'Collection'
  end
end
