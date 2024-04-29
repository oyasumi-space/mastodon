# frozen_string_literal: true

require 'rails_helper'

describe Api::V1::Circles::AccountsController do
  render_views

  let(:user)  { Fabricate(:user) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:circle)  { Fabricate(:circle, account: user.account) }
  let(:follow) { Fabricate(:follow, target_account: user.account) }

  before do
    circle.accounts << follow.account
    allow(controller).to receive(:doorkeeper_token) { token }
  end

  describe 'GET #index' do
    let(:scopes) { 'read:lists' }

    it 'returns http success' do
      get :show, params: { circle_id: circle.id }

      expect(response).to have_http_status(200)
    end
  end

  describe 'POST #create' do
    let(:scopes) { 'write:lists' }
    let(:bob) { Fabricate(:account, username: 'bob') }

    context 'when the added account is followed' do
      before do
        bob.follow!(user.account)
        post :create, params: { circle_id: circle.id, account_ids: [bob.id] }
      end

      it 'returns http success' do
        expect(response).to have_http_status(200)
      end

      it 'adds account to the circle' do
        expect(circle.accounts.include?(bob)).to be true
      end
    end

    context 'when the added account has been sent a follow request' do
      before do
        bob.follow_requests.create!(target_account: user.account)
        post :create, params: { circle_id: circle.id, account_ids: [bob.id] }
      end

      it 'returns http success' do
        expect(response).to have_http_status(404)
      end

      it 'adds account to the circle' do
        expect(circle.accounts.include?(bob)).to be false
      end
    end

    context 'when the added account is not followed' do
      before do
        post :create, params: { circle_id: circle.id, account_ids: [bob.id] }
      end

      it 'returns http not found' do
        expect(response).to have_http_status(404)
      end

      it 'does not add the account to the circle' do
        expect(circle.accounts.include?(bob)).to be false
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:scopes) { 'write:lists' }

    before do
      delete :destroy, params: { circle_id: circle.id, account_ids: [circle.accounts.first.id] }
    end

    it 'returns http success' do
      expect(response).to have_http_status(200)
    end

    it 'removes account from the circle' do
      expect(circle.accounts.count).to eq 0
    end
  end
end
