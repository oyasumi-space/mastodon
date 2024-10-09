# frozen_string_literal: true

class MoveAccountWarningNotifications < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  class Notification < ApplicationRecord; end

  def up
    Notification.where(type: 'warning').in_batches.update_all(type: 'moderation_warning')
  end

  def down
    Notification.where(type: 'moderation_warning').in_batches.update_all(type: 'warning')
  end
end
