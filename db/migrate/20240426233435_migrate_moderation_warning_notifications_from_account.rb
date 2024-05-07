# frozen_string_literal: true

class MigrateModerationWarningNotificationsFromAccount < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  class Notification < ApplicationRecord; end

  def up
    Notification.where(type: 'moderation_warning').in_batches.update_all('from_account_id = account_id')
  end

  # No need to reinstate this information as it is a privacy issue.
  def down; end
end
