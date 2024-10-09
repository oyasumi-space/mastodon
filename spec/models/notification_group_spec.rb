# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationGroup do
  subject { described_class.from_notifications([notification]) }

  context 'when favourite notifications' do
    let(:target_status)  { Fabricate(:status) }
    let(:alice)          { Fabricate(:account) }
    let(:bob)            { Fabricate(:account) }
    let(:favourite)      { Fabricate(:favourite, account: alice, status: target_status) }
    let(:notification)   { Fabricate(:notification, account: target_status.account, activity: favourite, group_key: group_key) }
    let(:group_key)      { 5 }

    it 'a simple case' do
      group = subject.first

      expect(group).to_not be_nil
      expect(group.notification.id).to eq notification.id
      expect(group.sample_accounts.pluck(:id)).to eq [alice.id]
    end

    it 'multiple reactors' do
      second = Fabricate(:favourite, account: bob, status: target_status)
      Fabricate(:notification, account: target_status.account, activity: second, group_key: group_key)

      group = subject.first

      expect(group).to_not be_nil
      expect(group.sample_accounts.pluck(:id)).to contain_exactly(alice.id, bob.id)
    end
  end

  context 'when emoji reaction notifications' do
    let(:target_status)  { Fabricate(:status) }
    let(:alice)          { Fabricate(:account) }
    let(:bob)            { Fabricate(:account) }
    let(:ohagi)          { Fabricate(:account) }
    let(:custom_emoji)   { Fabricate(:custom_emoji) }
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: alice, status: target_status, name: custom_emoji.shortcode, custom_emoji: custom_emoji) }
    let(:notification)   { Fabricate(:notification, account: target_status.account, activity: emoji_reaction, group_key: group_key) }
    let(:group_key)      { 5 }

    it 'with single emoji_reaction' do
      group = subject.first&.emoji_reaction_groups&.first

      expect(group).to_not be_nil
      expect(group.emoji_reaction.id).to eq emoji_reaction.id
      expect(group.sample_accounts.map(&:id)).to contain_exactly(alice.id)
    end

    context 'when group_key is not defined' do
      let(:group_key) { nil }

      it 'with single emoji_reaction' do
        group = subject.first&.emoji_reaction_groups&.first

        expect(group).to_not be_nil
        expect(group.emoji_reaction.id).to eq emoji_reaction.id
        expect(group.sample_accounts.map(&:id)).to contain_exactly(alice.id)
      end
    end

    it 'with multiple reactions' do
      second = Fabricate(:emoji_reaction, account: bob, status: target_status, name: custom_emoji.shortcode, custom_emoji: custom_emoji)
      Fabricate(:notification, account: target_status.account, activity: second, group_key: group_key)

      group = subject.first&.emoji_reaction_groups&.first

      expect(group).to_not be_nil
      expect([emoji_reaction.id, second.id]).to include group.emoji_reaction.id
      expect(group.sample_accounts.map(&:id)).to contain_exactly(alice.id, bob.id)
    end

    it 'with multiple reactions and multiple emojis' do
      second = Fabricate(:emoji_reaction, account: bob, status: target_status, name: custom_emoji.shortcode, custom_emoji: custom_emoji)
      Fabricate(:notification, account: target_status.account, activity: second, group_key: group_key)
      third = Fabricate(:emoji_reaction, account: ohagi, status: target_status, name: '😀')
      Fabricate(:notification, account: target_status.account, activity: third, group_key: group_key)

      group = subject.first.emoji_reaction_groups.find { |g| g.emoji_reaction.name == custom_emoji.shortcode }
      second_group = subject.first.emoji_reaction_groups.find { |g| g.emoji_reaction.name == '😀' }

      expect(group).to_not be_nil
      expect([emoji_reaction.id, second.id]).to include group.emoji_reaction.id
      expect(group.sample_accounts.map(&:id)).to contain_exactly(alice.id, bob.id)

      expect(second_group).to_not be_nil
      expect(third.id).to eq second_group.emoji_reaction.id
      expect(second_group.sample_accounts.map(&:id)).to contain_exactly(ohagi.id)
    end
  end
end
