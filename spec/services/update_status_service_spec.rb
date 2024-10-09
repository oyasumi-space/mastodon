# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateStatusService do
  subject { described_class.new }

  context 'when nothing changes' do
    let!(:status) { Fabricate(:status, text: 'Foo', language: 'en') }

    before do
      allow(ActivityPub::DistributionWorker).to receive(:perform_async)
    end

    it 'does not create an edit or notify anyone' do
      subject.call(status, status.account_id, text: 'Foo')

      expect(status.reload.edits)
        .to be_empty
      expect(ActivityPub::DistributionWorker)
        .to_not have_received(:perform_async)
    end
  end

  context 'when text changes' do
    let(:status) { Fabricate(:status, text: 'Foo') }
    let(:preview_card) { Fabricate(:preview_card) }

    before do
      PreviewCardsStatus.create(status: status, preview_card: preview_card)
    end

    it 'updates text, resets card, saves edit history' do
      subject.call(status, status.account_id, text: 'Bar')

      expect(status.reload)
        .to have_attributes(
          text: 'Bar',
          preview_card: be_nil
        )
      expect(status.edits.ordered.pluck(:text)).to eq %w(Foo Bar)
    end
  end

  context 'when content warning changes' do
    let(:status) { Fabricate(:status, text: 'Foo', spoiler_text: '') }
    let(:preview_card) { Fabricate(:preview_card) }

    before do
      PreviewCardsStatus.create(status: status, preview_card: preview_card)
    end

    it 'updates content warning and saves history' do
      subject.call(status, status.account_id, text: 'Foo', spoiler_text: 'Bar')

      expect(status.reload.spoiler_text)
        .to eq 'Bar'
      expect(status.edits.ordered.pluck(:text, :spoiler_text))
        .to eq [['Foo', ''], ['Foo', 'Bar']]
    end
  end

  context 'when content warning changes and has remote user', :inline_jobs do
    let(:remote_follower) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor', protocol: :activitypub, inbox_url: 'https://example.com/inbox') }
    let(:status) { Fabricate(:status, text: 'Foo', spoiler_text: '', account: Fabricate(:user).account) }

    before do
      remote_follower.follow!(status.account)
      stub_request(:post, 'https://example.com/inbox').to_return(status: 200)
    end

    def match_update_request(req, type)
      json = JSON.parse(req.body)
      actor_id = ActivityPub::TagManager.instance.uri_for(status.account)
      status_id = ActivityPub::TagManager.instance.uri_for(status)
      json['type'] == type && json['actor'] == actor_id && json['object']['id'] == status_id
    end

    it 'edit activity is sent' do
      subject.call(status, status.account_id, text: 'Foo', spoiler_text: 'Bar')

      expect(a_request(:post, 'https://example.com/inbox').with { |req| match_update_request(req, 'Update') }).to have_been_made.once
      expect(a_request(:post, 'https://example.com/inbox').with { |req| match_update_request(req, 'Delete') }).to_not have_been_made
    end

    it 'edit activity is sent for target user' do
      Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_send_sensitive: true)
      subject.call(status, status.account_id, text: 'Ohagi')

      expect(a_request(:post, 'https://example.com/inbox').with { |req| match_update_request(req, 'Update') }).to have_been_made.once
      expect(a_request(:post, 'https://example.com/inbox').with { |req| match_update_request(req, 'Delete') }).to_not have_been_made
    end

    it 'delete activity is sent when follower is target user' do
      Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_send_sensitive: true)
      subject.call(status, status.account_id, text: 'Foo', spoiler_text: 'Bar')

      expect(a_request(:post, 'https://example.com/inbox').with { |req| match_update_request(req, 'Delete') }).to have_been_made.once
      expect(a_request(:post, 'https://example.com/inbox').with { |req| match_update_request(req, 'Update') }).to_not have_been_made
    end

    it 'delete activity is sent and update activity is not sent when follower is target user' do
      Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_send_sensitive: true)
      subject.call(status, status.account_id, text: 'Foo', spoiler_text: 'Bar')
      subject.call(status, status.account_id, text: 'Ohagi', spoiler_text: 'Bar')

      expect(a_request(:post, 'https://example.com/inbox').with { |req| match_update_request(req, 'Delete') }).to have_been_made.once
      expect(a_request(:post, 'https://example.com/inbox').with { |req| match_update_request(req, 'Update') }).to_not have_been_made
    end
  end

  context 'when media attachments change' do
    let!(:status) { Fabricate(:status, text: 'Foo') }
    let!(:detached_media_attachment) { Fabricate(:media_attachment, account: status.account) }
    let!(:attached_media_attachment) { Fabricate(:media_attachment, account: status.account) }

    before do
      status.media_attachments << detached_media_attachment
    end

    it 'updates media attachments, handles attachments, saves history' do
      subject.call(status, status.account_id, text: 'Foo', media_ids: [attached_media_attachment.id.to_s])

      expect(status.ordered_media_attachments)
        .to eq [attached_media_attachment]
      expect(detached_media_attachment.reload.status_id)
        .to eq status.id
      expect(attached_media_attachment.reload.status_id)
        .to eq status.id
      expect(status.edits.ordered.pluck(:ordered_media_attachment_ids))
        .to eq [[detached_media_attachment.id], [attached_media_attachment.id]]
    end
  end

  context 'when already-attached media changes' do
    let!(:status) { Fabricate(:status, text: 'Foo') }
    let!(:media_attachment) { Fabricate(:media_attachment, account: status.account, description: 'Old description') }

    before do
      status.media_attachments << media_attachment
    end

    it 'does not detach media attachment, updates description, and saves history' do
      subject.call(status, status.account_id, text: 'Foo', media_ids: [media_attachment.id.to_s], media_attributes: [{ id: media_attachment.id, description: 'New description' }])

      expect(media_attachment.reload)
        .to have_attributes(
          status_id: status.id,
          description: 'New description'
        )
      expect(status.edits.ordered.map { |edit| edit.ordered_media_attachments.map(&:description) })
        .to eq [['Old description'], ['New description']]
    end
  end

  context 'when poll changes' do
    let(:account) { Fabricate(:account) }
    let!(:status) { Fabricate(:status, text: 'Foo', account: account, poll_attributes: { options: %w(Foo Bar), account: account, multiple: false, hide_totals: false, expires_at: 7.days.from_now }) }
    let!(:poll)   { status.poll }
    let!(:voter) { Fabricate(:account) }

    before do
      status.update(poll: poll)
      VoteService.new.call(voter, poll, [0])
    end

    it 'updates poll, resets votes, saves history, requeues notifications' do
      subject.call(status, status.account_id, text: 'Foo', poll: { options: %w(Bar Baz Foo), expires_in: 5.days.to_i })

      poll = status.poll.reload

      expect(poll)
        .to have_attributes(
          options: %w(Bar Baz Foo),
          votes_count: 0,
          cached_tallies: [0, 0, 0]
        )
      expect(poll.votes.count)
        .to eq(0)

      expect(status.edits.ordered.pluck(:poll_options))
        .to eq [%w(Foo Bar), %w(Bar Baz Foo)]

      expect(PollExpirationNotifyWorker)
        .to have_enqueued_sidekiq_job(poll.id).at(poll.expires_at + 5.minutes)
    end
  end

  context 'when mentions in text change' do
    let!(:account) { Fabricate(:account) }
    let!(:alice) { Fabricate(:account, username: 'alice') }
    let!(:bob) { Fabricate(:account, username: 'bob') }
    let!(:status) { PostStatusService.new.call(account, text: 'Hello @alice') }

    it 'changes mentions and keeps old as silent' do
      subject.call(status, status.account_id, text: 'Hello @bob')

      expect(status.active_mentions.pluck(:account_id))
        .to eq [bob.id]
      expect(status.mentions.pluck(:account_id))
        .to contain_exactly(alice.id, bob.id)
    end
  end

  context 'when personal_limited mentions in text change' do
    let!(:account) { Fabricate(:account) }
    let!(:bob) { Fabricate(:account, username: 'bob') }
    let!(:status) { PostStatusService.new.call(account, text: 'Hello', visibility: 'circle', circle_id: Fabricate(:circle, account: account).id) }

    before do
      subject.call(status, status.account_id, text: 'Hello @bob')
    end

    it 'changes mentions' do
      expect(status.active_mentions.pluck(:account_id)).to eq [bob.id]
    end

    it 'changes visibilities' do
      expect(status.visibility).to eq 'limited'
      expect(status.limited_scope).to eq 'circle'
    end
  end

  context 'when personal_limited in text change' do
    let!(:account) { Fabricate(:account) }
    let!(:status) { PostStatusService.new.call(account, text: 'Hello', visibility: 'circle', circle_id: Fabricate(:circle, account: account).id) }

    before do
      subject.call(status, status.account_id, text: 'AAA')
    end

    it 'not changing visibilities' do
      expect(status.visibility).to eq 'limited'
      expect(status.limited_scope).to eq 'personal'
    end
  end

  context 'when hashtags in text change' do
    let!(:account) { Fabricate(:account) }
    let!(:status) { PostStatusService.new.call(account, text: 'Hello #foo') }

    it 'changes tags' do
      subject.call(status, status.account_id, text: 'Hello #bar')

      expect(status.tags.pluck(:name)).to eq %w(bar)
    end
  end

  it 'notifies ActivityPub about the update' do
    status = Fabricate(:status, text: 'Foo')
    allow(ActivityPub::DistributionWorker).to receive(:perform_async)
    subject.call(status, status.account_id, text: 'Bar')
    expect(ActivityPub::DistributionWorker).to have_received(:perform_async)
  end

  describe 'ng word is set' do
    let(:account) { Fabricate(:account) }
    let(:status) { PostStatusService.new.call(account, text: 'ohagi') }

    it 'hit ng words' do
      text = 'ng word test'
      Fabricate(:ng_word, keyword: 'test', stranger: false)

      expect { subject.call(status, status.account_id, text: text) }.to raise_error(Mastodon::ValidationError)
    end

    it 'bypass ng words' do
      text = 'ng word test'
      Fabricate(:ng_word, keyword: 'test', stranger: false)

      expect { subject.call(status, status.account_id, text: text, bypass_validation: true) }.to_not raise_error
    end

    it 'not hit ng words' do
      text = 'ng word aiueo'
      Fabricate(:ng_word, keyword: 'test', stranger: false)

      status2 = subject.call(status, status.account_id, text: text)

      expect(status2).to be_persisted
      expect(status2.text).to eq text
    end

    it 'hit ng words for mention' do
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test')

      expect { subject.call(status, status.account_id, text: text) }.to raise_error(Mastodon::ValidationError)
      expect(status.reload.text).to_not eq text
      expect(status.mentioned_accounts.pluck(:username)).to_not include 'ohagi'
    end

    it 'hit ng words for mention but local posts are not checked' do
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '0').save
      Fabricate(:ng_word, keyword: 'test')

      status2 = subject.call(status, status.account_id, text: text)

      expect(status2).to be_persisted
      expect(status2.text).to eq text
    end

    it 'hit ng words for mention to follower' do
      mentioned = Fabricate(:account, username: 'ohagi', domain: nil)
      mentioned.follow!(account)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test')

      status2 = subject.call(status, status.account_id, text: text)

      expect(status2).to be_persisted
      expect(status2.text).to eq text
    end

    it 'hit ng words for reply' do
      text = 'ng word test'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test')

      status = PostStatusService.new.call(account, text: 'hello', thread: Fabricate(:status))

      expect { subject.call(status, status.account_id, text: text) }.to raise_error(Mastodon::ValidationError)
      expect(status.reload.text).to_not eq text
    end

    it 'hit ng words for reply to follower' do
      mentioned = Fabricate(:account, username: 'ohagi', domain: nil)
      mentioned.follow!(account)
      text = 'ng word test'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test')

      status = PostStatusService.new.call(account, text: 'hello', thread: Fabricate(:status, account: mentioned))

      status = subject.call(status, status.account_id, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'add reference' do
      target_status = Fabricate(:status)
      text = "ng word test BT: #{ActivityPub::TagManager.instance.uri_for(target_status)}"

      status = PostStatusService.new.call(account, text: 'hello')

      status = subject.call(status, status.account_id, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
      expect(status.references.pluck(:id)).to include target_status.id
    end

    it 'hit ng words for reference' do
      target_status = Fabricate(:status)
      text = "ng word test BT: #{ActivityPub::TagManager.instance.uri_for(target_status)}"
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test')

      status = PostStatusService.new.call(account, text: 'hello')

      expect { subject.call(status, status.account_id, text: text) }.to raise_error(Mastodon::ValidationError)
    end

    it 'hit ng words for reference to follower' do
      target_status = Fabricate(:status)
      target_status.account.follow!(status.account)
      text = "ng word test BT: #{ActivityPub::TagManager.instance.uri_for(target_status)}"
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test')

      status = PostStatusService.new.call(account, text: 'hello')

      status = subject.call(status, status.account_id, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'using hashtag under limit' do
      text = '#a #b'
      Form::AdminSettings.new(post_hash_tags_max: 2).save

      subject.call(status, status.account_id, text: text)

      expect(status.reload.tags.count).to eq 2
      expect(status.text).to eq text
    end

    it 'using hashtag over limit' do
      text = '#a #b #c'
      Form::AdminSettings.new(post_hash_tags_max: 2).save

      expect { subject.call(status, status.account_id, text: text) }.to raise_error Mastodon::ValidationError

      expect(status.reload.tags.count).to eq 0
      expect(status.text).to_not eq text
    end
  end

  describe 'ng rule is set' do
    let(:status) { Fabricate(:status, text: 'Foo') }

    context 'when rule hits' do
      before do
        Fabricate(:ng_rule, status_text: 'Bar', status_allow_follower_mention: false)
      end

      it 'does not update text' do
        expect { subject.call(status, status.account_id, text: 'Bar') }.to raise_error Mastodon::ValidationError
        expect(status.reload.text).to_not eq 'Bar'
        expect(status.edits.pluck(:text)).to eq %w()
      end
    end

    context 'when rule does not hit' do
      before do
        Fabricate(:ng_rule, status_text: 'aar', status_allow_follower_mention: false)
      end

      it 'does not update text' do
        expect { subject.call(status, status.account_id, text: 'Bar') }.to_not raise_error
        expect(status.reload.text).to eq 'Bar'
        expect(status.edits.pluck(:text)).to eq %w(Foo Bar)
      end
    end
  end
end
