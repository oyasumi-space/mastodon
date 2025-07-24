# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::Activity::Accept do
  let(:sender)    { Fabricate(:account) }
  let(:recipient) { Fabricate(:account) }

  describe '#perform' do
    subject { described_class.new(json, sender) }

    context 'with a Follow request' do
      let(:json) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Accept',
          actor: ActivityPub::TagManager.instance.uri_for(sender),
          object: {
            id: 'https://abc-123/456',
            type: 'Follow',
            actor: ActivityPub::TagManager.instance.uri_for(recipient),
            object: ActivityPub::TagManager.instance.uri_for(sender),
          },
        }.deep_stringify_keys
      end

      context 'with a regular Follow' do
        before do
          Fabricate(:follow_request, account: recipient, target_account: sender)
        end

        it 'creates a follow relationship, removes the follow request, and queues a refresh' do
          expect { subject.perform }
            .to change { recipient.following?(sender) }.from(false).to(true)
            .and change { recipient.requested?(sender) }.from(true).to(false)

          expect(RemoteAccountRefreshWorker).to have_enqueued_sidekiq_job(sender.id)
        end
      end

      context 'when given a relay' do
        let!(:relay) { Fabricate(:relay, state: :pending, follow_activity_id: 'https://abc-123/456') }

        it 'marks the relay as accepted' do
          expect { subject.perform }
            .to change { relay.reload.accepted? }.from(false).to(true)
        end
      end
    end
  end

  context 'when sender is from friend server' do
    subject { described_class.new(json, sender) }

    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: 'foo',
        type: 'Accept',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        object: {
          id: 'bar',
          type: 'Follow',
          actor: ActivityPub::TagManager.instance.uri_for(recipient),
          object: ActivityPub::TagManager.instance.uri_for(sender),
        },
      }.with_indifferent_access
    end

    let(:sender) { Fabricate(:account, domain: 'abc.com', url: 'https://abc.com/#actor') }
    let!(:friend) { Fabricate(:friend_domain, domain: 'abc.com', active_state: :pending, active_follow_activity_id: 'https://abc-123/456') }

    before do
      allow(RemoteAccountRefreshWorker).to receive(:perform_async)
      Fabricate(:follow_request, account: recipient, target_account: sender)
      subject.perform
    end

    it 'creates a follow relationship' do
      expect(recipient.following?(sender)).to be true
    end

    it 'removes the follow request' do
      expect(recipient.requested?(sender)).to be false
    end

    it 'queues a refresh' do
      expect(RemoteAccountRefreshWorker).to have_received(:perform_async).with(sender.id)
    end

    it 'friend server is not changed' do
      expect(friend.reload.i_am_pending?).to be true
    end
  end

  context 'when given a friend server' do
    subject { described_class.new(json, sender) }

    let(:sender) { Fabricate(:account, domain: 'abc.com', url: 'https://abc.com/#actor') }
    let!(:friend) { Fabricate(:friend_domain, domain: 'abc.com', active_state: :pending, active_follow_activity_id: 'https://abc-123/456') }

    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: 'foo',
        type: 'Accept',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        object: 'https://abc-123/456',
      }.with_indifferent_access
    end

    it 'marks the friend as accepted' do
      subject.perform
      expect(friend.reload.i_am_accepted?).to be true
    end

    it 'when the friend server is pending' do
      friend.update(passive_state: :pending)
      subject.perform
      expect(friend.reload.they_are_idle?).to be true
      expect(friend.i_am_accepted?).to be true
    end

    it 'when the friend server is accepted' do
      friend.update(passive_state: :accepted)
      subject.perform
      expect(friend.reload.they_are_idle?).to be true
      expect(friend.i_am_accepted?).to be true
    end

    it 'when my server is not pending' do
      friend.update(active_state: :idle)
      subject.perform
      expect(friend.reload.i_am_idle?).to be true
      expect(friend.they_are_idle?).to be true
    end
  end
end
