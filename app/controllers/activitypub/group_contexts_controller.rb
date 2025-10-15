# frozen_string_literal: true

class ActivityPub::GroupContextsController < ActivityPub::BaseController
  vary_by -> { 'Signature' if authorized_fetch_mode? }

  before_action :set_context

  def show
    expires_in 3.minutes, public: public_fetch_mode?
    render json: @context,
           serializer: ActivityPub::GroupContextSerializer,
           adapter: ActivityPub::Adapter,
           content_type: 'application/activity+json'
  end

  private

  def account_required?
    false
  end

  def set_context
    @context = Conversation.find(params[:id])
  end
end
