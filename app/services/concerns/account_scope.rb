# frozen_string_literal: true

module AccountScope
  def scope_status(status)
    case status.visibility.to_sym
    when :public, :unlisted, :public_unlisted, :login
      scope_local
    when :private
      scope_account_local_followers(status.account)
    else
      scope_status_mentioned(status)
    end
  end

  def scope_local
    Account.local.select(:id)
  end

  def scope_account_local_followers(account)
    account.followers_for_local_distribution.select(:id).reorder(nil)
  end

  def scope_status_mentioned(status)
    status.active_mentions.joins(:account).merge(Account.local).select('account_id AS id').reorder(nil)
  end

  # TODO: not work
  def scope_list_following_account(account)
    account.lists_for_local_distribution.select(:id).reorder(nil)
  end

  def scope_tag_following_account(_status)
    TagFollow.where(tag_id: @status.tags.map(&:id)).select('account_id AS id').reorder(nil)
  end
end
