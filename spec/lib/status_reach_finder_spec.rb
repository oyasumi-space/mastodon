# frozen_string_literal: true

require 'rails_helper'

describe StatusReachFinder do
  describe '#inboxes' do
    context 'with a local status' do
      subject { described_class.new(status) }

      let(:parent_status) { nil }
      let(:visibility) { :public }
      let(:alice) { Fabricate(:account, username: 'alice') }
      let(:status) { Fabricate(:status, account: alice, thread: parent_status, visibility: visibility) }

      context 'with a simple case' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        context 'with follower' do
          before do
            bob.follow!(alice)
          end

          it 'send status' do
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
          end
        end

        context 'with non-follower' do
          it 'send status' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when misskey case with unlisted post' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }
        let(:sender_software) { 'mastodon' }
        let(:visibility) { :unlisted }

        before do
          Fabricate(:instance_info, domain: 'foo.bar', software: sender_software)
          bob.follow!(alice)
        end

        context 'when mastodon' do
          it 'send status' do
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_misskey).to_not include 'https://foo.bar/inbox'
          end
        end

        context 'when misskey' do
          let(:sender_software) { 'misskey' }

          it 'send status without setting' do
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_misskey).to_not include 'https://foo.bar/inbox'
          end

          it 'send status with setting' do
            alice.user.settings.update(reject_unlisted_subscription: 'true')
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_misskey).to include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when it contains mentions of remote accounts' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        before do
          status.mentions.create!(account: bob)
        end

        it 'includes the inbox of the mentioned account' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end
      end

      context 'when it has been reblogged by a remote account' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        before do
          bob.statuses.create!(reblog: status)
        end

        it 'includes the inbox of the reblogger' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end

        context 'when status is not public' do
          let(:visibility) { :private }

          it 'does not include the inbox of the reblogger' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when it has been favourited by a remote account' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        before do
          bob.favourites.create!(status: status)
        end

        it 'includes the inbox of the favouriter' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end

        context 'when status is not public' do
          let(:visibility) { :private }

          it 'does not include the inbox of the favouriter' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when it has been replied to by a remote account' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        before do
          bob.statuses.create!(thread: status, text: 'Hoge')
        end

        it 'includes the inbox of the replier' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end

        context 'when status is not public' do
          let(:visibility) { :private }

          it 'does not include the inbox of the replier' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when it is a reply to a remote account' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }
        let(:parent_status) { Fabricate(:status, account: bob) }

        it 'includes the inbox of the replied-to account' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end

        context 'when status is not public and replied-to account is not mentioned' do
          let(:visibility) { :private }

          it 'does not include the inbox of the replied-to account' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
          end
        end
      end
    end

    context 'with extended domain block' do
      subject do
        described_class.new(status)
      end

      before do
        bob.follow!(alice)
        tom.follow!(alice)
        Fabricate(:domain_block, domain: 'example.com', severity: 'noop', **properties)
      end

      let(:properties) { {} }
      let(:visibility) { :public }
      let(:searchability) { :public }
      let(:dissubscribable) { false }
      let(:spoiler_text) { '' }
      let(:status) { Fabricate(:status, account: alice, visibility: visibility, searchability: searchability, spoiler_text: spoiler_text) }
      let(:alice) { Fabricate(:account, username: 'alice', dissubscribable: dissubscribable) }
      let(:bob) { Fabricate(:account, username: 'bob', domain: 'example.com', protocol: :activitypub, uri: 'https://example.com/', inbox_url: 'https://example.com/inbox') }
      let(:tom) { Fabricate(:account, username: 'tom', domain: 'tom.com', protocol: :activitypub, uri: 'https://tom.com/', inbox_url: 'https://tom.com/inbox') }

      context 'when reject_send_sensitive' do
        let(:properties) { { reject_send_sensitive: true } }
        let(:spoiler_text) { 'CW' }

        it 'does not include the inbox of blocked domain' do
          expect(subject.inboxes).to_not include 'https://example.com/inbox'
          expect(subject.inboxes).to include 'https://tom.com/inbox'
        end
      end
    end
  end
end
