# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PostStatusService do
  subject { described_class.new }

  it 'creates a new status' do
    account = Fabricate(:account)
    text = 'test status update'

    status = subject.call(account, text: text)

    expect(status).to be_persisted
    expect(status.text).to eq text
  end

  it 'creates a new response status' do
    in_reply_to_status = Fabricate(:status)
    account = Fabricate(:account)
    text = 'test status update'

    status = subject.call(account, text: text, thread: in_reply_to_status)

    expect(status).to be_persisted
    expect(status.text).to eq text
    expect(status.thread).to eq in_reply_to_status
  end

  context 'when scheduling a status' do
    let!(:account)         { Fabricate(:account) }
    let!(:future)          { Time.now.utc + 2.hours }
    let!(:previous_status) { Fabricate(:status, account: account) }

    it 'schedules a status for future creation and does not create one immediately' do
      media = Fabricate(:media_attachment, account: account)
      status = subject.call(account, text: 'Hi future!', media_ids: [media.id.to_s], scheduled_at: future)

      expect(status)
        .to be_a(ScheduledStatus)
        .and have_attributes(
          scheduled_at: eq(future),
          params: include(
            'text' => eq('Hi future!'),
            'media_ids' => contain_exactly(media.id.to_s)
          )
        )
      expect(media.reload.status).to be_nil
      expect(Status.where(text: 'Hi future!')).to_not exist
    end

    it 'does not change statuses_count of account or replies_count of thread previous status' do
      expect { subject.call(account, text: 'Hi future!', scheduled_at: future, thread: previous_status) }
        .to not_change { account.statuses_count }
        .and(not_change { previous_status.replies_count })
    end

    it 'returns existing status when used twice with idempotency key' do
      account = Fabricate(:account)
      status1 = subject.call(account, text: 'test', idempotency: 'meepmeep', scheduled_at: future)
      status2 = subject.call(account, text: 'test', idempotency: 'meepmeep', scheduled_at: future)
      expect(status2.id).to eq status1.id
    end

    context 'when scheduled_at is less than min offset' do
      let(:invalid_scheduled_time) { 4.minutes.from_now }

      it 'raises invalid record error' do
        expect do
          subject.call(account, text: 'Hi future!', scheduled_at: invalid_scheduled_time)
        end.to raise_error(
          ActiveRecord::RecordInvalid,
          'Validation failed: Scheduled at The scheduled date must be in the future'
        )
      end
    end

    it 'returns existing status when used twice with idempotency key' do
      account = Fabricate(:account)
      status1 = subject.call(account, text: 'test', idempotency: 'meepmeep', scheduled_at: future)
      status2 = subject.call(account, text: 'test', idempotency: 'meepmeep', scheduled_at: future)
      expect(status2.id).to eq status1.id
    end

    context 'when scheduled_at is less than min offset' do
      let(:invalid_scheduled_time) { 4.minutes.from_now }

      it 'raises invalid record error' do
        expect do
          subject.call(account, text: 'Hi future!', scheduled_at: invalid_scheduled_time)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  it 'creates response to the original status of boost' do
    boosted_status = Fabricate(:status)
    in_reply_to_status = Fabricate(:status, reblog: boosted_status)
    account = Fabricate(:account)
    text = 'test status update'

    status = subject.call(account, text: text, thread: in_reply_to_status)

    expect(status).to be_persisted
    expect(status.text).to eq text
    expect(status.thread).to eq boosted_status
  end

  it 'creates a sensitive status' do
    status = create_status_with_options(sensitive: true)

    expect(status).to be_persisted
    expect(status).to be_sensitive
  end

  it 'creates a status with spoiler text' do
    spoiler_text = 'spoiler text'

    status = create_status_with_options(spoiler_text: spoiler_text)

    expect(status).to be_persisted
    expect(status.spoiler_text).to eq spoiler_text
  end

  it 'creates a sensitive status when there is a CW but no text' do
    status = subject.call(Fabricate(:account), text: '', spoiler_text: 'foo')

    expect(status).to be_persisted
    expect(status).to be_sensitive
  end

  it 'creates a status with empty default spoiler text' do
    status = create_status_with_options(spoiler_text: nil)

    expect(status).to be_persisted
    expect(status.spoiler_text).to eq ''
  end

  it 'creates a status with the given visibility' do
    status = create_status_with_options(visibility: :private)

    expect(status).to be_persisted
    expect(status.visibility).to eq 'private'
  end

  it 'raises on an invalid visibility' do
    expect do
      create_status_with_options(visibility: :xxx)
    end.to raise_error(
      ActiveRecord::RecordInvalid,
      'Validation failed: Visibility is not included in the list'
    )
  end

  it 'creates a status with limited visibility for silenced users' do
    status = subject.call(Fabricate(:account, silenced: true), text: 'test', visibility: :public)

    expect(status).to be_persisted
    expect(status.visibility).to eq 'unlisted'
  end

  it 'creates a status with the given searchability' do
    status = create_status_with_options(searchability: :public, visibility: :public)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'public'
  end

  it 'creates a status with limited searchability for silenced users' do
    status = subject.call(Fabricate(:account, silenced: true), text: 'test', searchability: :public, visibility: :public)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'private'
  end

  it 'creates a status with limited searchability for silenced users with public_unlisted searchability' do
    status = subject.call(Fabricate(:account, silenced: true), text: 'test', searchability: :public_unlisted, visibility: :public)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'private'
  end

  it 'creates a status with the given searchability=public / visibility=unlisted' do
    status = create_status_with_options(searchability: :public, visibility: :unlisted)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'public'
  end

  it 'creates a status with the given searchability=public_unlisted / visibility=unlisted' do
    status = create_status_with_options(searchability: :public_unlisted, visibility: :unlisted)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'public_unlisted'
  end

  it 'creates a status with the given searchability=public / visibility=private' do
    status = create_status_with_options(searchability: :public, visibility: :private)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'private'
  end

  it 'creates a status with the given searchability=public_unlisted / visibility=private' do
    status = create_status_with_options(searchability: :public_unlisted, visibility: :private)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'private'
  end

  it 'creates a status for the given application' do
    application = Fabricate(:application)

    status = create_status_with_options(application: application)

    expect(status).to be_persisted
    expect(status.application).to eq application
  end

  it 'creates a status with a language set' do
    account = Fabricate(:account)
    text = 'This is an English text.'

    status = subject.call(account, text: text)

    expect(status.language).to eq 'en'
  end

  it 'processes mentions' do
    mention_service = instance_double(ProcessMentionsService)
    allow(mention_service).to receive(:call)
    allow(ProcessMentionsService).to receive(:new).and_return(mention_service)
    account = Fabricate(:account)

    status = subject.call(account, text: 'test status update')

    expect(ProcessMentionsService).to have_received(:new)
    expect(mention_service).to have_received(:call).with(status, limited_type: '', circle: nil, save_records: false)
  end

  it 'self-banned visibility is set' do
    user = Fabricate(:user)
    user.settings.update(disabled_visibilities: ['public_unlisted'])

    expect { subject.call(user.account, text: 'text', visibility: 'public_unlisted') }.to raise_error ActiveRecord::RecordInvalid
  end

  it 'self-banned visibility is not set' do
    user = Fabricate(:user)
    user.settings.update(disabled_visibilities: ['public_unlisted'])

    expect { subject.call(user.account, text: 'text', visibility: 'unlisted') }.to_not raise_error
  end

  context 'with mutual visibility' do
    let(:sender) { Fabricate(:user).account }
    let(:io_account) { Fabricate(:account, domain: 'misskey.io', uri: 'https://misskey.io/actor') }
    let(:local_account) { Fabricate(:account) }
    let(:remote_account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
    let(:follower) { Fabricate(:account) }
    let(:followee) { Fabricate(:account) }

    before do
      Fabricate(:instance_info, domain: 'misskey.io', software: 'misskey')
      io_account.follow!(sender)
      local_account.follow!(sender)
      remote_account.follow!(sender)
      follower.follow!(sender)
      sender.follow!(io_account)
      sender.follow!(local_account)
      sender.follow!(remote_account)
      sender.follow!(followee)
    end

    it 'visibility is set' do
      status = subject.call(sender, text: 'text', visibility: 'mutual')

      expect(status.visibility).to eq 'limited'
      expect(status.limited_scope).to eq 'mutual'
    end

    it 'sent to mutuals' do
      status = subject.call(sender, text: 'text', visibility: 'mutual')

      expect(status.mentioned_accounts.count).to eq 3
      expect(status.mentioned_accounts.pluck(:id)).to contain_exactly(io_account.id, local_account.id, remote_account.id)
    end

    it 'sent to mutuals without misskey.io users' do
      sender.user.update!(settings: { reject_send_limited_to_suspects: true })

      status = subject.call(sender, text: 'text', visibility: 'mutual')

      expect(status.mentioned_accounts.count).to eq 2
      expect(status.mentioned_accounts.pluck(:id)).to contain_exactly(local_account.id, remote_account.id)
    end
  end

  it 'limited visibility and direct searchability' do
    account = Fabricate(:account)
    text = 'This is an English text.'

    status = subject.call(account, text: text, visibility: 'mutual', searchability: 'public')

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'personal'
    expect(status.searchability).to eq 'direct'
  end

  it 'personal visibility with mutual' do
    account = Fabricate(:account)
    text = 'This is an English text.'

    status = subject.call(account, text: text, visibility: 'mutual')

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'personal'
    expect(status.mentioned_accounts.count).to eq 0
  end

  it 'circle visibility' do
    account = Fabricate(:account)
    circle_account = Fabricate(:account)
    other_account = Fabricate(:account)
    circle = Fabricate(:circle, account: account)
    text = 'This is an English text.'

    circle_account.follow!(account)
    other_account.follow!(account)
    circle.accounts << circle_account
    status = subject.call(account, text: text, visibility: 'circle', circle_id: circle.id)

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'circle'
    expect(status.mentioned_accounts.count).to eq 1
    expect(status.mentioned_accounts.first.id).to eq circle_account.id
  end

  it 'circle post with limited visibility' do
    account = Fabricate(:account)
    circle_account = Fabricate(:account)
    circle = Fabricate(:circle, account: account)
    text = 'This is an English text.'

    circle_account.follow!(account)
    circle.accounts << circle_account
    status = subject.call(account, text: text, visibility: 'limited', circle_id: circle.id)

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'circle'
  end

  it 'limited visibility without circle' do
    account = Fabricate(:account)
    text = 'This is an English text.'

    expect { subject.call(account, text: text, visibility: 'limited') }.to raise_exception ActiveRecord::RecordInvalid
  end

  it 'personal visibility with circle' do
    account = Fabricate(:account)
    circle = Fabricate(:circle, account: account)
    text = 'This is an English text.'

    status = subject.call(account, text: text, visibility: 'circle', circle_id: circle.id)

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'personal'
    expect(status.mentioned_accounts.count).to eq 0
  end

  it 'using empty circle but with mention' do
    account = Fabricate(:account)
    Fabricate(:account, username: 'bob', domain: nil)
    circle = Fabricate(:circle, account: account)
    text = 'This is an English text. @bob'

    status = subject.call(account, text: text, visibility: 'circle', circle_id: circle.id)

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'circle'
    expect(status.mentioned_accounts.count).to eq 1
  end

  describe 'create a new response status to limited post' do
    it 'when reply visibility' do
      in_reply_to_status = Fabricate(:status, visibility: :limited)
      account = Fabricate(:account)
      text = 'test status update'

      status = subject.call(account, text: text, thread: in_reply_to_status, visibility: 'reply')

      expect(status).to be_persisted
      expect(status.thread).to eq in_reply_to_status
      expect(status.visibility).to eq 'limited'
      expect(status.limited_scope).to eq 'reply'
    end

    it 'when limited visibility' do
      in_reply_to_status = Fabricate(:status, visibility: :limited)
      account = Fabricate(:account)
      text = 'test status update'

      status = subject.call(account, text: text, thread: in_reply_to_status, visibility: 'limited')

      expect(status).to be_persisted
      expect(status.thread).to eq in_reply_to_status
      expect(status.visibility).to eq 'limited'
      expect(status.limited_scope).to eq 'reply'
    end

    it 'when circle visibility' do
      in_reply_to_status = Fabricate(:status, visibility: :limited)
      account = Fabricate(:account)
      text = 'test status update'

      circle = Fabricate(:circle, account: account)
      circle_account = Fabricate(:account)
      circle_account.follow!(account)
      circle.accounts << circle_account
      circle.save!

      status = subject.call(account, text: text, thread: in_reply_to_status, visibility: 'circle', circle_id: circle.id)

      expect(status).to be_persisted
      expect(status.thread).to eq in_reply_to_status
      expect(status.visibility).to eq 'limited'
      expect(status.limited_scope).to eq 'circle'
      expect(status.mentioned_accounts.pluck(:id)).to eq [circle_account.id]
    end

    it 'when public visibility' do
      in_reply_to_status = Fabricate(:status, visibility: :limited)
      account = Fabricate(:account)
      text = 'test status update'

      status = subject.call(account, text: text, thread: in_reply_to_status, visibility: :public)

      expect(status).to be_persisted
      expect(status.thread).to eq in_reply_to_status
      expect(status.visibility).to eq 'public'
    end

    it 'when direct visibility' do
      in_reply_to_status = Fabricate(:status, visibility: :limited)
      account = Fabricate(:account)
      text = 'test status update'

      status = subject.call(account, text: text, thread: in_reply_to_status, visibility: :direct)

      expect(status).to be_persisted
      expect(status.thread).to eq in_reply_to_status
      expect(status.visibility).to eq 'direct'
    end

    it 'duplicate replies' do
      in_reply_to_status = Fabricate(:status, visibility: :limited)
      in_reply_to_status.mentions.create!(account: Fabricate(:account))

      status = subject.call(Fabricate(:user).account, text: 'Ohagi is good', thread: in_reply_to_status, visibility: 'reply')

      thread_account_ids = [in_reply_to_status.account, in_reply_to_status.mentions.first.account].map(&:id)

      expect(status).to be_persisted
      expect(status.conversation_id).to eq in_reply_to_status.conversation_id
      expect(status.conversation.ancestor_status_id).to eq in_reply_to_status.id
      expect(status.mentions.pluck(:account_id)).to match_array thread_account_ids
    end

    it 'duplicate reply-to-reply' do
      ancestor_account = Fabricate(:account, username: 'ancestor', domain: nil)
      reply_account = Fabricate(:account)

      first_status = Fabricate(:status, account: ancestor_account, visibility: :limited)
      in_reply_to_status = subject.call(reply_account, text: 'Ohagi is good, @ancestor', thread: first_status, visibility: 'reply')
      status = subject.call(ancestor_account, text: 'Ohagi is good', thread: in_reply_to_status, visibility: 'reply')

      thread_account_ids = [ancestor_account, reply_account].map(&:id)

      expect(status).to be_persisted
      expect(status.conversation_id).to eq in_reply_to_status.conversation_id
      expect(status.conversation_id).to eq first_status.conversation_id
      expect(status.conversation.ancestor_status_id).to eq first_status.id
      expect(status.mentions.pluck(:account_id)).to match_array thread_account_ids
    end

    it 'duplicate reply-to-third_reply' do
      first_status = Fabricate(:status, visibility: :limited)
      first_status.mentions.create!(account: Fabricate(:account))

      mentioned_account = Fabricate(:account, username: 'ohagi', domain: nil)
      mentioned_account2 = Fabricate(:account, username: 'bob', domain: nil)
      in_reply_to_status = subject.call(Fabricate(:user).account, text: 'Ohagi is good, @ohagi', thread: first_status, visibility: 'reply')
      status = subject.call(Fabricate(:user).account, text: 'Ohagi is good, @bob', thread: in_reply_to_status, visibility: 'reply')

      thread_account_ids = [first_status.account, first_status.mentions.first.account, mentioned_account, mentioned_account2, in_reply_to_status.account].map(&:id)

      expect(status).to be_persisted
      expect(status.conversation_id).to eq in_reply_to_status.conversation_id
      expect(status.conversation_id).to eq first_status.conversation_id
      expect(status.conversation.ancestor_status_id).to eq first_status.id
      expect(status.mentions.pluck(:account_id)).to match_array thread_account_ids
    end

    it 'do not duplicate replies when limited post' do
      in_reply_to_status = Fabricate(:status, visibility: :limited)
      in_reply_to_status.mentions.create!(account: Fabricate(:account))

      status = subject.call(Fabricate(:user).account, text: 'Ohagi is good', thread: in_reply_to_status, visibility: 'mutual')

      [in_reply_to_status.account, in_reply_to_status.mentions.first.account].map(&:id)

      expect(status).to be_persisted
      expect(status.limited_scope).to eq 'personal'

      mentions = status.mentions.pluck(:account_id)
      expect(mentions).to_not include in_reply_to_status.account_id
      expect(mentions).to_not include in_reply_to_status.mentions.first.account_id
    end

    it 'do not duplicate replies when not limited post' do
      in_reply_to_status = Fabricate(:status, visibility: :limited)
      in_reply_to_status.mentions.create!(account: Fabricate(:account))

      status = subject.call(Fabricate(:user).account, text: 'Ohagi is good', thread: in_reply_to_status, visibility: 'public')

      [in_reply_to_status.account, in_reply_to_status.mentions.first.account].map(&:id)

      expect(status).to be_persisted

      mentions = status.mentions.pluck(:account_id)
      expect(mentions).to_not include in_reply_to_status.account_id
      expect(mentions).to_not include in_reply_to_status.mentions.first.account_id
    end
  end

  it 'safeguards mentions' do
    account = Fabricate(:account)
    mentioned_account = Fabricate(:account, username: 'alice')
    unexpected_mentioned_account = Fabricate(:account, username: 'bob')

    expect do
      subject.call(account, text: '@alice hm, @bob is really annoying lately', allowed_mentions: [mentioned_account.id])
    end.to raise_error(an_instance_of(described_class::UnexpectedMentionsError).and(having_attributes(accounts: [unexpected_mentioned_account])))
  end

  it 'processes duplicate mentions correctly' do
    account = Fabricate(:account)
    Fabricate(:account, username: 'alice')

    expect do
      subject.call(account, text: '@alice @alice @alice hey @alice')
    end.to_not raise_error
  end

  it 'processes hashtags' do
    hashtags_service = instance_double(ProcessHashtagsService)
    allow(hashtags_service).to receive(:call)
    allow(ProcessHashtagsService).to receive(:new).and_return(hashtags_service)
    account = Fabricate(:account)

    status = subject.call(account, text: 'test status update')

    expect(ProcessHashtagsService).to have_received(:new)
    expect(hashtags_service).to have_received(:call).with(status)
  end

  it 'gets distributed' do
    allow(DistributionWorker).to receive(:perform_async)
    allow(ActivityPub::DistributionWorker).to receive(:perform_async)

    account = Fabricate(:account)

    status = subject.call(account, text: 'test status update')

    expect(DistributionWorker).to have_received(:perform_async).with(status.id)
    expect(ActivityPub::DistributionWorker).to have_received(:perform_async).with(status.id)
  end

  it 'gets distributed when personal post' do
    allow(DistributionWorker).to receive(:perform_async)
    allow(ActivityPub::DistributionWorker).to receive(:perform_async)

    account = Fabricate(:account)

    empty_circle = Fabricate(:circle, account: account)
    status = subject.call(account, text: 'test status update', visibility: 'circle', circle_id: empty_circle.id)

    expect(DistributionWorker).to have_received(:perform_async).with(status.id)
    expect(ActivityPub::DistributionWorker).to_not have_received(:perform_async).with(status.id)
  end

  it 'crawls links' do
    allow(LinkCrawlWorker).to receive(:perform_async)
    account = Fabricate(:account)

    status = subject.call(account, text: 'test status update')

    expect(LinkCrawlWorker).to have_received(:perform_async).with(status.id)
  end

  it 'attaches the given media to the created status' do
    account = Fabricate(:account)
    media = Fabricate(:media_attachment, account: account)

    status = subject.call(
      account,
      text: 'test status update',
      media_ids: [media.id.to_s]
    )

    expect(media.reload.status).to eq status
  end

  it 'does not attach media from another account to the created status' do
    account = Fabricate(:account)
    media = Fabricate(:media_attachment, account: Fabricate(:account))

    expect do
      subject.call(
        account,
        text: 'test status update',
        media_ids: [media.id.to_s]
      )
    end.to raise_error(
      Mastodon::ValidationError,
      I18n.t('media_attachments.validations.not_found', ids: media.id)
    )
  end

  it 'does not allow attaching more files than configured limit' do
    stub_const('Status::MEDIA_ATTACHMENTS_LIMIT', 1)
    account = Fabricate(:account)

    expect do
      subject.call(
        account,
        text: 'test status update',
        media_ids: Array.new(2) { Fabricate(:media_attachment, account: account) }.map { |m| m.id.to_s }
      )
    end.to raise_error(
      Mastodon::ValidationError,
      I18n.t('media_attachments.validations.too_many')
    )
  end

  it 'does not allow attaching both videos and images' do
    account = Fabricate(:account)
    video   = Fabricate(:media_attachment, type: :video, account: account)
    image   = Fabricate(:media_attachment, type: :image, account: account)

    video.update(type: :video)

    expect do
      subject.call(
        account,
        text: 'test status update',
        media_ids: [
          video,
          image,
        ].map { |m| m.id.to_s }
      )
    end.to raise_error(
      Mastodon::ValidationError,
      I18n.t('media_attachments.validations.images_and_video')
    )
  end

  it 'returns existing status when used twice with idempotency key' do
    account = Fabricate(:account)
    status1 = subject.call(account, text: 'test', idempotency: 'meepmeep')
    status2 = subject.call(account, text: 'test', idempotency: 'meepmeep')
    expect(status2.id).to eq status1.id
  end

  describe 'ng word is set' do
    it 'hit ng words' do
      account = Fabricate(:account)
      text = 'ng word test'
      Fabricate(:ng_word, keyword: 'test', stranger: false)

      expect { subject.call(account, text: text) }.to raise_error(Mastodon::ValidationError)
    end

    it 'not hit ng words' do
      account = Fabricate(:account)
      text = 'ng word aiueo'
      Fabricate(:ng_word, keyword: 'test', stranger: false)

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'hit ng words for mention' do
      account = Fabricate(:account)
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test', stranger: true)

      expect { subject.call(account, text: text) }.to raise_error(Mastodon::ValidationError)
    end

    it 'hit ng words for mention but local posts are not checked' do
      account = Fabricate(:account)
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '0').save
      Fabricate(:ng_word, keyword: 'test', stranger: true)

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'hit ng words for mention to follower' do
      account = Fabricate(:account)
      mentioned = Fabricate(:account, username: 'ohagi', domain: nil)
      mentioned.follow!(account)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test', stranger: true)

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'does not hit ng words for mention to self' do
      account = Fabricate(:account, username: 'cool', domain: nil)
      text = 'ng word test @cool'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test', stranger: true)

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'hit ng words for reply' do
      account = Fabricate(:account)
      text = 'ng word test'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test', stranger: true)

      expect { subject.call(account, text: text, thread: Fabricate(:status)) }.to raise_error(Mastodon::ValidationError)
    end

    it 'hit ng words for reply to follower' do
      account = Fabricate(:account)
      mentioned = Fabricate(:account, username: 'ohagi', domain: nil)
      mentioned.follow!(account)
      text = 'ng word test'
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test', stranger: true)

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'with a reference' do
      target_status = Fabricate(:status)
      account = Fabricate(:account)
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = "ref BT: #{ActivityPub::TagManager.instance.uri_for(target_status)}"

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
      expect(status.references.pluck(:id)).to include target_status.id
    end

    it 'hit ng words for reference' do
      target_status = Fabricate(:status)
      account = Fabricate(:account)
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = "ng word test BT: #{ActivityPub::TagManager.instance.uri_for(target_status)}"
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test', stranger: true)

      expect { subject.call(account, text: text) }.to raise_error(Mastodon::ValidationError)
    end

    it 'hit ng words for reference to follower' do
      target_status = Fabricate(:status)
      account = Fabricate(:account)
      target_status.account.follow!(account)
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = "ng word test BT: #{ActivityPub::TagManager.instance.uri_for(target_status)}"
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test', stranger: true)

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'does not hit ng words for reference to self' do
      target_status = Fabricate(:status)
      account = target_status.account
      text = "ng word test BT: #{ActivityPub::TagManager.instance.uri_for(target_status)}"
      Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
      Fabricate(:ng_word, keyword: 'test', stranger: true)

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'using hashtag under limit' do
      account = Fabricate(:account)
      text = '#a #b'
      Form::AdminSettings.new(post_hash_tags_max: 2).save

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.tags.count).to eq 2
      expect(status.text).to eq text
    end

    it 'using hashtag over limit' do
      account = Fabricate(:account)
      text = '#a #b #c'
      Form::AdminSettings.new(post_hash_tags_max: 2).save

      expect { subject.call(account, text: text) }.to raise_error Mastodon::ValidationError
    end

    it 'using mentions under limit' do
      a = Fabricate(:account, username: 'a')
      b = Fabricate(:account, username: 'b')
      account = Fabricate(:account)
      a.follow!(account)
      b.follow!(account)
      text = '@a @b'
      Form::AdminSettings.new(post_mentions_max: 2).save

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'using mentions over limit' do
      a = Fabricate(:account, username: 'a')
      b = Fabricate(:account, username: 'b')
      account = Fabricate(:account)
      a.follow!(account)
      b.follow!(account)
      text = '@a @b'
      Form::AdminSettings.new(post_mentions_max: 1).save

      expect { subject.call(account, text: text) }.to raise_error Mastodon::ValidationError
    end

    it 'using mentions for stranger under limit' do
      Fabricate(:account, username: 'a')
      Fabricate(:account, username: 'b')
      account = Fabricate(:account)
      text = '@a @b'
      Form::AdminSettings.new(post_stranger_mentions_max: 2).save

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'using mentions for stranger over limit' do
      Fabricate(:account, username: 'a')
      Fabricate(:account, username: 'b')
      account = Fabricate(:account)
      text = '@a @b'
      Form::AdminSettings.new(post_stranger_mentions_max: 1).save

      expect { subject.call(account, text: text) }.to raise_error Mastodon::ValidationError
    end

    it 'using mentions for stranger over limit but normal setting is under limit' do
      a = Fabricate(:account, username: 'a')
      b = Fabricate(:account, username: 'b')
      account = Fabricate(:account)
      a.follow!(account)
      b.follow!(account)
      text = '@a @b'
      Form::AdminSettings.new(post_mentions_max: 2, post_stranger_mentions_max: 1).save

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'using mentions for stranger over limit but normal setting is under limit when following one only' do
      a = Fabricate(:account, username: 'a')
      b = Fabricate(:account, username: 'b')
      Fabricate(:account, username: 'c')
      account = Fabricate(:account)
      a.follow!(account)
      b.follow!(account)
      text = '@a @b @c'
      Form::AdminSettings.new(post_mentions_max: 3, post_stranger_mentions_max: 2).save

      expect { subject.call(account, text: text) }.to raise_error Mastodon::ValidationError
    end
  end

  describe 'ng rule is set' do
    it 'creates a new status when no rule matches' do
      Fabricate(:ng_rule, account_username: 'ohagi', status_allow_follower_mention: false)
      account = Fabricate(:account)
      text = 'test status update'

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'does not create a new status when a rule matches' do
      Fabricate(:ng_rule, status_text: 'test', status_allow_follower_mention: false)
      account = Fabricate(:account)
      text = 'test status update'

      expect { subject.call(account, text: text) }.to raise_error Mastodon::ValidationError
    end
  end

  def create_status_with_options(**options)
    subject.call(Fabricate(:account), options.merge(text: 'test'))
  end
end
