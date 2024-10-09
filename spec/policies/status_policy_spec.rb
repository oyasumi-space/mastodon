# frozen_string_literal: true

require 'rails_helper'
require 'pundit/rspec'

RSpec.describe StatusPolicy, type: :model do
  subject { described_class }

  let(:admin) { Fabricate(:user, role: UserRole.find_by(name: 'Admin')) }
  let(:alice) { Fabricate(:account, username: 'alice') }
  let(:bob) { Fabricate(:account, username: 'bob') }
  let(:status) { Fabricate(:status, account: alice) }

  context 'with the permissions of show? and reblog?' do
    permissions :show?, :reblog? do
      it 'grants access when no viewer' do
        expect(subject).to permit(nil, status)
      end

      it 'denies access when viewer is blocked' do
        block = Fabricate(:block)
        status.visibility = :private
        status.account = block.target_account

        expect(subject).to_not permit(block.account, status)
      end
    end
  end

  context 'with the permission of show?' do
    permissions :show? do
      it 'grants access when direct and account is viewer' do
        status.visibility = :direct

        expect(subject).to permit(status.account, status)
      end

      it 'grants access when direct and viewer is mentioned' do
        status.visibility = :direct
        status.mentions = [Fabricate(:mention, account: alice)]

        expect(subject).to permit(alice, status)
      end

      it 'grants access when direct and non-owner viewer is mentioned and mentions are loaded' do
        status.visibility = :direct
        status.mentions = [Fabricate(:mention, account: bob)]
        status.mentions.load

        expect(subject).to permit(bob, status)
      end

      it 'denies access when direct and viewer is not mentioned' do
        viewer = Fabricate(:account)
        status.visibility = :direct

        expect(subject).to_not permit(viewer, status)
      end

      it 'grants access when limited and account is viewer' do
        status.visibility = :limited

        expect(subject).to permit(status.account, status)
      end

      it 'grants access when limited and viewer is mentioned' do
        status.visibility = :limited
        status.mentions = [Fabricate(:mention, account: alice)]

        expect(subject).to permit(alice, status)
      end

      it 'grants access when limited and non-owner viewer is mentioned and mentions are loaded' do
        status.visibility = :limited
        status.mentions = [Fabricate(:mention, account: bob)]
        status.mentions.load

        expect(subject).to permit(bob, status)
      end

      it 'denies access when limited and viewer is not mentioned' do
        viewer = Fabricate(:account)
        status.visibility = :limited

        expect(subject).to_not permit(viewer, status)
      end

      it 'grants access when private and account is viewer' do
        status.visibility = :private

        expect(subject).to permit(status.account, status)
      end

      it 'grants access when private and account is following viewer' do
        follow = Fabricate(:follow)
        status.visibility = :private
        status.account = follow.target_account

        expect(subject).to permit(follow.account, status)
      end

      it 'grants access when private and viewer is mentioned' do
        status.visibility = :private
        status.mentions = [Fabricate(:mention, account: alice)]

        expect(subject).to permit(alice, status)
      end

      it 'denies access when private and viewer is not mentioned or followed' do
        viewer = Fabricate(:account)
        status.visibility = :private

        expect(subject).to_not permit(viewer, status)
      end

      context 'with remote account' do
        let(:viewer) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
        let(:status) { Fabricate(:status, account: alice, spoiler_text: 'ohagi', sensitive: true) }

        it 'grants access when viewer is not domain-blocked' do
          expect(subject).to permit(viewer, status)
        end

        it 'denies access when viewer is domain-blocked' do
          Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_send_sensitive: true)

          expect(subject).to_not permit(viewer, status)
        end
      end
    end
  end

  context 'with the permission of show_mentioned_users?' do
    permissions :show_mentioned_users? do
      it 'grants access when public and account is viewer' do
        status.visibility = :public

        expect(subject).to permit(status.account, status)
      end

      it 'grants access when public and account is not viewer' do
        status.visibility = :public

        expect(subject).to_not permit(bob, status)
      end

      it 'grants access when limited and no conversation ancestor_status and account is viewer' do
        status.visibility = :limited
        status.conversation = Fabricate(:conversation)

        expect(subject).to permit(status.account, status)
      end

      it 'grants access when limited and my conversation and account is viewer' do
        status.visibility = :limited
        status.conversation = Fabricate(:conversation, ancestor_status: status)

        expect(subject).to permit(status.account, status)
      end

      it 'grants access when limited and another conversation and account is viewer' do
        status.visibility = :limited
        status.conversation = Fabricate(:conversation, ancestor_status: Fabricate(:status, account: bob))

        expect(subject).to_not permit(status.account, status)
      end

      it 'grants access when limited and viewer is mentioned' do
        status.visibility = :limited
        status.mentions = [Fabricate(:mention, account: bob)]

        expect(subject).to_not permit(bob, status)
      end

      it 'grants access when limited and non-owner viewer is mentioned and mentions are loaded' do
        status.visibility = :limited
        status.mentions = [Fabricate(:mention, account: bob)]
        status.mentions.load

        expect(subject).to_not permit(bob, status)
      end
    end
  end

  context 'with the permission of reblog?' do
    permissions :reblog? do
      it 'denies access when private' do
        viewer = Fabricate(:account)
        status.visibility = :private

        expect(subject).to_not permit(viewer, status)
      end

      it 'denies access when direct' do
        viewer = Fabricate(:account)
        status.visibility = :direct

        expect(subject).to_not permit(viewer, status)
      end
    end
  end

  context 'with the permissions of destroy? and unreblog?' do
    permissions :destroy?, :unreblog? do
      it 'grants access when account is deleter' do
        expect(subject).to permit(status.account, status)
      end

      it 'denies access when account is not deleter' do
        expect(subject).to_not permit(bob, status)
      end

      it 'denies access when no deleter' do
        expect(subject).to_not permit(nil, status)
      end
    end
  end

  context 'with the permission of favourite?' do
    permissions :favourite? do
      it 'grants access when viewer is not blocked' do
        follow         = Fabricate(:follow)
        status.account = follow.target_account

        expect(subject).to permit(follow.account, status)
      end

      it 'denies when viewer is blocked' do
        block          = Fabricate(:block)
        status.account = block.target_account

        expect(subject).to_not permit(block.account, status)
      end
    end
  end

  context 'with the permission of emoji_reaction?' do
    permissions :emoji_reaction? do
      it 'grants access when viewer is not blocked' do
        follow         = Fabricate(:follow)
        status.account = follow.target_account

        expect(subject).to permit(follow.account, status)
      end

      it 'denies when viewer is blocked' do
        block          = Fabricate(:block)
        status.account = block.target_account

        expect(subject).to_not permit(block.account, status)
      end
    end
  end

  context 'with the permission of quote?' do
    permissions :quote? do
      it 'grants access when viewer is not blocked' do
        follow         = Fabricate(:follow)
        status.account = follow.target_account

        expect(subject).to permit(follow.account, status)
      end

      it 'denies when viewer is blocked' do
        block          = Fabricate(:block)
        status.account = block.target_account

        expect(subject).to_not permit(block.account, status)
      end

      it 'denies when private visibility' do
        status.visibility = :private

        expect(subject).to_not permit(Fabricate(:account), status)
      end
    end
  end

  context 'with the permission of update?' do
    permissions :update? do
      it 'grants access if owner' do
        expect(subject).to permit(status.account, status)
      end
    end
  end
end
