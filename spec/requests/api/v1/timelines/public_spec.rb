# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public' do
  let(:user)    { Fabricate(:user) }
  let(:scopes)  { 'read:statuses' }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }
  let(:ltl_enabled) { true }

  shared_examples 'a successful request to the public timeline' do
    it 'returns the expected statuses successfully', :aggregate_failures do
      Form::AdminSettings.new(enable_local_timeline: '0').save unless ltl_enabled

      subject

      expect(response).to have_http_status(200)
      expect(response.content_type)
        .to start_with('application/json')
      expect(response.parsed_body.pluck(:id)).to match_array(expected_statuses.map { |status| status.id.to_s })
    end
  end

  describe 'GET /api/v1/timelines/public' do
    subject do
      get '/api/v1/timelines/public', headers: headers, params: params
    end

    let!(:local_status)   { Fabricate(:status, text: 'ohagi', account: Fabricate.build(:account, domain: nil)) }
    let!(:remote_status)  { Fabricate(:status, text: 'ohagi', account: Fabricate.build(:account, domain: 'example.com')) }
    let!(:media_status)   { Fabricate(:status, text: 'ohagi', media_attachments: [Fabricate.build(:media_attachment)]) }
    let(:params) { {} }

    before do
      Fabricate(:status, visibility: :private)
    end

    context 'when the instance allows public preview' do
      let(:expected_statuses) { [local_status, remote_status, media_status] }

      it_behaves_like 'forbidden for wrong scope', 'profile'

      context 'with an authorized user' do
        it_behaves_like 'a successful request to the public timeline'
      end

      context 'with an anonymous user' do
        let(:headers) { {} }

        it_behaves_like 'a successful request to the public timeline'
      end

      context 'with local param' do
        let(:params) { { local: true } }
        let(:expected_statuses) { [local_status, media_status] }

        it_behaves_like 'a successful request to the public timeline'

        context 'when local timeline is disabled' do
          let(:expected_statuses) { [] }
          let(:ltl_enabled) { false }

          it_behaves_like 'a successful request to the public timeline'
        end
      end

      context 'with remote param' do
        let(:params) { { remote: true } }
        let(:expected_statuses) { [remote_status] }

        it_behaves_like 'a successful request to the public timeline'

        context 'when local timeline is disabled' do
          let(:ltl_enabled) { false }
          let(:expected_statuses) { [local_status, remote_status, media_status] }

          it_behaves_like 'a successful request to the public timeline'
        end
      end

      context 'with local and remote params' do
        let(:params) { { local: true, remote: true } }
        let(:expected_statuses) { [local_status, remote_status, media_status] }

        it_behaves_like 'a successful request to the public timeline'

        context 'when local timeline is disabled' do
          let(:ltl_enabled) { false }

          it_behaves_like 'a successful request to the public timeline'
        end
      end

      context 'with only_media param' do
        let(:params) { { only_media: true } }
        let(:expected_statuses) { [media_status] }

        it_behaves_like 'a successful request to the public timeline'
      end

      context 'with limit param' do
        let(:params) { { limit: 1 } }

        it 'returns only the requested number of statuses and sets pagination headers', :aggregate_failures do
          subject

          expect(response).to have_http_status(200)
          expect(response.content_type)
            .to start_with('application/json')
          expect(response.parsed_body.size).to eq(params[:limit])

          expect(response)
            .to include_pagination_headers(
              prev: api_v1_timelines_public_url(limit: params[:limit], min_id: media_status.id),
              next: api_v1_timelines_public_url(limit: params[:limit], max_id: media_status.id)
            )
        end
      end
    end

    context 'when the instance does not allow public preview' do
      before do
        Form::AdminSettings.new(timeline_preview: false).save
      end

      it_behaves_like 'forbidden for wrong scope', 'profile'

      context 'without an authentication token' do
        let(:headers) { {} }

        it 'returns http unprocessable entity' do
          subject

          expect(response).to have_http_status(422)
          expect(response.content_type)
            .to start_with('application/json')
        end
      end

      context 'with an application access token, not bound to a user' do
        let(:token) { Fabricate(:accessible_access_token, resource_owner_id: nil, scopes: scopes) }

        it 'returns http unprocessable entity' do
          subject

          expect(response).to have_http_status(422)
          expect(response.content_type)
            .to start_with('application/json')
        end
      end

      context 'with an authenticated user' do
        let(:expected_statuses) { [local_status, remote_status, media_status] }

        it_behaves_like 'a successful request to the public timeline'
      end
    end

    context 'when user is setting filters' do
      subject do
        get '/api/v1/timelines/public', headers: headers, params: params
        response.parsed_body.filter { |status| status[:filtered].empty? || status[:filtered][0][:filter][:id] != filter.id.to_s }.map { |status| status[:id].to_i }
      end

      before do
        Fabricate(:custom_filter_keyword, custom_filter: filter, keyword: 'ohagi')
        Fabricate(:follow, account: account, target_account: remote_account)
      end

      let(:exclude_follows) { false }
      let(:exclude_localusers) { false }
      let(:include_quotes) { false }
      let(:account) { user.account }
      let(:remote_account) { remote_status.account }
      let!(:filter) { Fabricate(:custom_filter, account: account, exclude_follows: exclude_follows, exclude_localusers: exclude_localusers, with_quote: include_quotes) }
      let!(:quote_status) { Fabricate(:status, quote: Fabricate(:status, text: 'ohagi')) }

      it 'load statuses', :aggregate_failures do
        ids = subject
        expect(ids).to_not include(local_status.id)
        expect(ids).to_not include(remote_status.id)
      end

      context 'when exclude_followers' do
        let(:exclude_follows) { true }

        it 'load statuses', :aggregate_failures do
          ids = subject
          expect(ids).to_not include(local_status.id)
          expect(ids).to include(remote_status.id)
        end
      end

      context 'when exclude_localusers' do
        let(:exclude_localusers) { true }

        it 'load statuses', :aggregate_failures do
          ids = subject
          expect(ids).to include(local_status.id)
          expect(ids).to_not include(remote_status.id)
        end
      end

      context 'when include_quotes' do
        let(:with_quote) { true }

        it 'load statuses', :aggregate_failures do
          ids = subject
          expect(ids).to_not include(local_status.id)
          expect(ids).to include(quote_status.id)
        end
      end

      context 'with an application access token, not bound to a user' do
        let(:token) { Fabricate(:accessible_access_token, resource_owner_id: nil, scopes: scopes) }

        it 'returns http unprocessable entity' do
          subject

          expect(response).to have_http_status(422)
        end
      end

      context 'with an authenticated user' do
        let(:expected_statuses) { [local_status, remote_status, media_status] }

        it_behaves_like 'a successful request to the public timeline'
      end
    end
  end
end
