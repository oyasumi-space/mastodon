# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::Activity::Reject do
  let(:sender)    { Fabricate(:account) }
  let(:recipient) { Fabricate(:account) }
  let(:object_json) do
    {
      id: 'bar',
      type: 'Follow',
      actor: ActivityPub::TagManager.instance.uri_for(recipient),
      object: ActivityPub::TagManager.instance.uri_for(sender),
    }
  end

  let(:json) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: 'foo',
      type: 'Reject',
      actor: ActivityPub::TagManager.instance.uri_for(sender),
      object: object_json,
    }.with_indifferent_access
  end

  describe '#perform' do
    subject { described_class.new(json, sender) }

    context 'when rejecting a pending follow request by target' do
      before do
        Fabricate(:follow_request, account: recipient, target_account: sender)
        subject.perform
      end

      it 'does not create a follow relationship' do
        expect(recipient.following?(sender)).to be false
      end

      it 'removes the follow request' do
        expect(recipient.requested?(sender)).to be false
      end
    end

    context 'when rejecting a pending follow request by uri' do
      before do
        Fabricate(:follow_request, account: recipient, target_account: sender, uri: 'bar')
        subject.perform
      end

      it 'does not create a follow relationship' do
        expect(recipient.following?(sender)).to be false
      end

      it 'removes the follow request' do
        expect(recipient.requested?(sender)).to be false
      end
    end

    context 'when rejecting a pending follow request by uri only' do
      let(:object_json) { 'bar' }

      before do
        Fabricate(:follow_request, account: recipient, target_account: sender, uri: 'bar')
        subject.perform
      end

      it 'does not create a follow relationship' do
        expect(recipient.following?(sender)).to be false
      end

      it 'removes the follow request' do
        expect(recipient.requested?(sender)).to be false
      end
    end

    context 'when rejecting an existing follow relationship by target' do
      before do
        Fabricate(:follow, account: recipient, target_account: sender)
        subject.perform
      end

      it 'removes the follow relationship' do
        expect(recipient.following?(sender)).to be false
      end

      it 'does not create a follow request' do
        expect(recipient.requested?(sender)).to be false
      end
    end

    context 'when rejecting an existing follow relationship by uri' do
      before do
        Fabricate(:follow, account: recipient, target_account: sender, uri: 'bar')
        subject.perform
      end

      it 'removes the follow relationship' do
        expect(recipient.following?(sender)).to be false
      end

      it 'does not create a follow request' do
        expect(recipient.requested?(sender)).to be false
      end
    end

    context 'when rejecting an existing follow relationship by uri only' do
      let(:object_json) { 'bar' }

      before do
        Fabricate(:follow, account: recipient, target_account: sender, uri: 'bar')
        subject.perform
      end

      it 'removes the follow relationship' do
        expect(recipient.following?(sender)).to be false
      end

      it 'does not create a follow request' do
        expect(recipient.requested?(sender)).to be false
      end
    end
  end

  context 'when sender is from friend server' do
    subject { described_class.new(json, sender) }

    let(:sender) { Fabricate(:account, domain: 'abc.com', url: 'https://abc.com/#actor') }
    let!(:friend) { Fabricate(:friend_domain, domain: 'abc.com', active_state: :pending, active_follow_activity_id: 'https://abc-123/456') }

    before do
      Fabricate(:follow_request, account: recipient, target_account: sender)
      subject.perform
    end

    it 'does not create a follow relationship' do
      expect(recipient.following?(sender)).to be false
    end

    it 'removes the follow request' do
      expect(recipient.requested?(sender)).to be false
    end

    it 'friend server is not changed' do
      expect(friend.reload.i_am_pending?).to be true
    end
  end

  context 'when given a relay' do
    subject { described_class.new(json, sender) }

    let!(:relay) { Fabricate(:relay, state: :pending, follow_activity_id: 'https://abc-123/456') }

    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: 'foo',
        type: 'Reject',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        object: {
          id: 'https://abc-123/456',
          type: 'Follow',
          actor: ActivityPub::TagManager.instance.uri_for(recipient),
          object: ActivityPub::TagManager.instance.uri_for(sender),
        },
      }.with_indifferent_access
    end

    it 'marks the relay as rejected' do
      subject.perform
      expect(relay.reload.rejected?).to be true
    end
  end

  context 'when given a friend' do
    subject { described_class.new(json, sender) }

    let(:sender) { Fabricate(:account, domain: 'abc.com', url: 'https://abc.com/#actor') }
    let!(:friend) { Fabricate(:friend_domain, domain: 'abc.com', active_state: :pending, active_follow_activity_id: 'https://abc-123/456') }

    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: 'foo',
        type: 'Reject',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        object: 'https://abc-123/456',
      }.with_indifferent_access
    end

    it 'marks the friend as rejected' do
      subject.perform
      expect(friend.reload.i_am_rejected?).to be true
    end

    it 'when the friend server is pending' do
      friend.update(passive_state: :pending)
      subject.perform
      expect(friend.reload.they_are_idle?).to be true
      expect(friend.i_am_rejected?).to be true
    end

    it 'when the friend server is accepted' do
      friend.update(passive_state: :accepted)
      subject.perform
      expect(friend.reload.they_are_idle?).to be true
      expect(friend.i_am_rejected?).to be true
    end
  end
end
