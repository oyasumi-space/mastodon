# frozen_string_literal: true

require 'rails_helper'

describe Api::V1::CirclesController do
  render_views

  let(:user) { Fabricate(:user) }
  let(:circle) { Fabricate(:circle, account: user.account) }

  before do
    allow(controller).to receive(:doorkeeper_token) { token }
  end

  context 'with a user context' do
    let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'read:lists') }

    describe 'GET #show' do
      it 'returns http success' do
        get :show, params: { id: circle.id }
        expect(response).to have_http_status(200)
      end
    end

    describe 'GET #index' do
      it 'returns http success' do
        circle_id = circle.id.to_s
        Fabricate(:circle)
        get :index
        expect(response).to have_http_status(200)

        circle_ids = body_as_json.pluck(:id)
        expect(circle_ids.size).to eq 1
        expect(circle_ids).to include circle_id
      end
    end
  end

  context 'with the wrong user context' do
    let(:other_user) { Fabricate(:user) }
    let(:token)      { Fabricate(:accessible_access_token, resource_owner_id: other_user.id, scopes: 'read') }

    describe 'GET #show' do
      it 'returns http not found' do
        get :show, params: { id: circle.id }
        expect(response).to have_http_status(404)
      end
    end
  end

  context 'without a user context' do
    let(:token) { Fabricate(:accessible_access_token, resource_owner_id: nil, scopes: 'read') }

    describe 'GET #show' do
      it 'returns http unprocessable entity' do
        get :show, params: { id: circle.id }

        expect(response).to have_http_status(422)
        expect(response.headers['Link']).to be_nil
      end
    end
  end
end
