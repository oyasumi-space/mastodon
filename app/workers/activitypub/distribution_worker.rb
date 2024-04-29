# frozen_string_literal: true

class ActivityPub::DistributionWorker < ActivityPub::RawDistributionWorker
  # Distribute a new status or an edit of a status to all the places
  # where the status is supposed to go or where it was interacted with
  def perform(status_id)
    @status  = Status.find(status_id)
    @account = @status.account

    if @status.limited_visibility?
      distribute_limited!
    else
      distribute!
    end
  rescue ActiveRecord::RecordNotFound
    true
  end

  protected

  def distribute_limited!
    ActivityPub::DeliveryWorker.push_bulk(inboxes_for_limited, limit: 1_000) do |inbox_url|
      [payload, @account.id, inbox_url, options]
    end
  end

  def inboxes
    @inboxes ||= status_reach_finder.inboxes
  end

  def inboxes_for_misskey
    @inboxes_for_misskey ||= status_reach_finder.inboxes_for_misskey
  end

  def inboxes_for_limited
    @inboxes_for_limited ||= status_reach_finder.inboxes_for_limited
  end

  def status_reach_finder
    @status_reach_finder ||= StatusReachFinder.new(@status)
  end

  def payload
    @payload ||= Oj.dump(serialize_payload(activity, ActivityPub::ActivitySerializer, signer: @account))
  end

  def payload_for_misskey
    @payload_for_misskey ||= Oj.dump(serialize_payload(activity_for_misskey, ActivityPub::ActivityForMisskeySerializer, signer: @account))
  end

  def activity
    ActivityPub::ActivityPresenter.from_status(@status)
  end

  def activity_for_misskey
    ActivityPub::ActivityPresenter.from_status(@status, for_misskey: true)
  end

  def options
    { 'synchronize_followers' => @status.private_visibility? }
  end
end
