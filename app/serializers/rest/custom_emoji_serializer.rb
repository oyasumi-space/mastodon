# frozen_string_literal: true

class REST::CustomEmojiSerializer < REST::CustomEmojiSlimSerializer
  include RoutingHelper

  attribute :aliases, if: :aliases?

  def aliases?
    object.respond_to?(:aliases) && object.aliases.present?
  end
end
