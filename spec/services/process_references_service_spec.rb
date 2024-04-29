# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessReferencesService, type: :service do
  let(:text) { 'Hello' }
  let(:account) { Fabricate(:user).account }
  let(:visibility) { :public }
  let(:target_status_visibility) { :public }
  let(:status) { Fabricate(:status, account: account, text: text, visibility: visibility) }
  let(:target_status) { Fabricate(:status, account: Fabricate(:user).account, visibility: target_status_visibility) }
  let(:target_status_uri) { ActivityPub::TagManager.instance.uri_for(target_status) }

  def notify?(target_status_id = nil)
    target_status_id ||= target_status.id
    StatusReference.exists?(id: Notification.where(type: 'status_reference').select(:activity_id), target_status_id: target_status_id)
  end

  describe 'posting new status' do
    subject do
      described_class.new.call(status, reference_parameters, urls: urls, fetch_remote: fetch_remote)
      status.reference_objects.pluck(:target_status_id, :attribute_type)
    end

    let(:reference_parameters) { [] }
    let(:urls) { [] }
    let(:fetch_remote) { true }

    context 'when a simple case' do
      let(:text) { "Hello RT #{target_status_uri}" }

      it 'post status' do
        expect(subject.size).to eq 1
        expect(subject.pluck(0)).to include target_status.id
        expect(subject.pluck(1)).to include 'RT'
        expect(notify?).to be true
      end
    end

    context 'when multiple references' do
      let(:target_status2) { Fabricate(:status) }
      let(:target_status2_uri) { ActivityPub::TagManager.instance.uri_for(target_status2) }
      let(:text) { "Hello RT #{target_status_uri}\nBT #{target_status2_uri}" }

      it 'post status' do
        expect(subject.size).to eq 2
        expect(subject).to include [target_status.id, 'RT']
        expect(subject).to include [target_status2.id, 'BT']
        expect(notify?).to be true
        expect(notify?(target_status2.id)).to be true
      end
    end

    context 'when private post' do
      let(:text) { "Hello RT #{target_status_uri}" }
      let(:visibility) { :private }

      it 'post status' do
        expect(subject.size).to eq 1
        expect(subject.pluck(0)).to include target_status.id
        expect(subject.pluck(1)).to include 'RT'
        expect(notify?).to be false
      end
    end

    context 'when cannot show private post' do
      let(:text) { "Hello RT #{target_status_uri}" }
      let(:target_status_visibility) { :private }

      it 'post status' do
        expect(subject.size).to eq 0
        expect(notify?).to be false
      end
    end

    context 'with quote' do
      let(:text) { "Hello QT #{target_status_uri}" }

      it 'post status' do
        expect(subject.size).to eq 1
        expect(subject.pluck(0)).to include target_status.id
        expect(subject.pluck(1)).to include 'QT'
        expect(status.quote).to_not be_nil
        expect(status.quote.id).to eq target_status.id
        expect(notify?).to be true
      end
    end

    context 'with quote and reference' do
      let(:target_status2) { Fabricate(:status) }
      let(:target_status2_uri) { ActivityPub::TagManager.instance.uri_for(target_status2) }
      let(:text) { "Hello QT #{target_status_uri}\nBT #{target_status2_uri}" }

      it 'post status' do
        expect(subject.size).to eq 2
        expect(subject).to include [target_status.id, 'QT']
        expect(subject).to include [target_status2.id, 'BT']
        expect(status.quote).to_not be_nil
        expect(status.quote.id).to eq target_status.id
        expect(notify?).to be true
        expect(notify?(target_status2.id)).to be true
      end
    end

    context 'when url only' do
      let(:text) { "Hello #{target_status_uri}" }

      it 'post status' do
        expect(subject.size).to eq 0
        expect(notify?).to be false
      end
    end

    context 'when unfetched remote post' do
      let(:account) { Fabricate(:account, followers_url: 'http://example.com/followers', domain: 'example.com', uri: 'https://example.com/actor') }
      let(:object_json) do
        {
          id: 'https://example.com/test_post',
          to: ActivityPub::TagManager::COLLECTIONS[:public],
          '@context': ActivityPub::TagManager::CONTEXT,
          type: 'Note',
          actor: account.uri,
          attributedTo: account.uri,
          content: 'Lorem ipsum',
          published: '2022-01-22T15:00:00Z',
          updated: '2022-01-22T16:00:00Z',
        }
      end
      let(:text) { 'BT:https://example.com/test_post' }

      before do
        stub_request(:get, 'https://example.com/test_post').to_return(status: 200, body: Oj.dump(object_json), headers: { 'Content-Type' => 'application/activity+json' })
        stub_request(:get, 'https://example.com/not_found').to_return(status: 404)
      end

      it 'reference it' do
        expect(subject.size).to eq 1
        expect(subject[0][1]).to eq 'BT'

        status = Status.find_by(id: subject[0][0])
        expect(status).to_not be_nil
        expect(status.url).to eq 'https://example.com/test_post'
      end

      context 'with fetch_remote later' do
        let(:fetch_remote) { false }

        it 'reference it' do
          ids = subject.pluck(0)
          expect(ids.size).to eq 1

          status = Status.find_by(id: ids[0])
          expect(status).to_not be_nil
          expect(status.url).to eq 'https://example.com/test_post'
        end
      end

      context 'with fetch_remote later with has existing reference' do
        let(:fetch_remote) { false }
        let(:text) { "RT #{ActivityPub::TagManager.instance.uri_for(target_status)} BT https://example.com/test_post" }

        it 'reference it' do
          expect(subject.size).to eq 2
          expect(subject).to include [target_status.id, 'RT']
          expect(subject.pluck(1)).to include 'BT'

          status = Status.find_by(id: subject.pluck(0), uri: 'https://example.com/test_post')
          expect(status).to_not be_nil
        end
      end

      context 'with not exists reference' do
        let(:text) { 'BT https://example.com/not_found' }

        it 'reference it' do
          expect(subject.size).to eq 0
        end
      end
    end
  end

  describe 'editing new status' do
    subject do
      status.update!(text: new_text)
      described_class.new.call(status, reference_parameters, urls: urls, fetch_remote: fetch_remote)
      status.references.pluck(:id)
    end

    let(:target_status2) { Fabricate(:status, account: Fabricate(:user).account) }
    let(:target_status2_uri) { ActivityPub::TagManager.instance.uri_for(target_status2) }

    let(:new_text) { 'Hello' }
    let(:reference_parameters) { [] }
    let(:urls) { [] }
    let(:fetch_remote) { true }

    before do
      described_class.new.call(status, reference_parameters, urls: urls, fetch_remote: fetch_remote)
    end

    context 'when add reference to empty' do
      let(:new_text) { "BT #{target_status_uri}" }

      it 'post status' do
        expect(subject.size).to eq 1
        expect(subject).to include target_status.id
        expect(notify?).to be true
      end
    end

    context 'when add reference to have anyone' do
      let(:text) { "BT #{target_status_uri}" }
      let(:new_text) { "BT #{target_status_uri}\nBT #{target_status2_uri}" }

      it 'post status' do
        expect(subject.size).to eq 2
        expect(subject).to include target_status.id
        expect(subject).to include target_status2.id
        expect(notify?(target_status2.id)).to be true
      end
    end

    context 'when add reference but has same' do
      let(:text) { "BT #{target_status_uri}" }
      let(:new_text) { "BT #{target_status_uri}\nBT #{target_status_uri}" }

      it 'post status' do
        expect(subject.size).to eq 1
        expect(subject).to include target_status.id
      end
    end

    context 'when remove reference' do
      let(:text) { "BT #{target_status_uri}" }
      let(:new_text) { 'Hello' }

      it 'post status' do
        expect(subject.size).to eq 0
        expect(notify?).to be false
      end
    end

    context 'when change reference' do
      let(:text) { "BT #{target_status_uri}" }
      let(:new_text) { "BT #{target_status2_uri}" }

      it 'post status' do
        expect(subject.size).to eq 1
        expect(subject).to include target_status2.id
        expect(notify?(target_status2.id)).to be true
      end
    end
  end
end
