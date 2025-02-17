# frozen_string_literal: true

class RemoveOldPublicIndexForOriginalToStatuses < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :statuses, [:id, :account_id], if_exists: true, name: :index_statuses_public_20231213, algorithm: :concurrently, order: { id: :desc }, where: 'deleted_at IS NULL AND visibility IN (0, 10, 11) AND reblog_of_id IS NULL AND ((NOT reply) OR (in_reply_to_account_id = account_id))' # rubocop:disable Naming/VariableNumber
    remove_index :statuses, [:id, :account_id], if_exists: true, name: :index_statuses_public_20200119, algorithm: :concurrently, order: { id: :desc }, where: 'deleted_at IS NULL AND visibility = 0 AND reblog_of_id IS NULL AND ((NOT reply) OR (in_reply_to_account_id = account_id))' # rubocop:disable Naming/VariableNumber
    remove_index :statuses, [:id, :language, :account_id], name: :index_statuses_public_20250129, algorithm: :concurrently, order: { id: :desc }, where: 'deleted_at IS NULL AND visibility = 0 AND reblog_of_id IS NULL AND ((NOT reply) OR (in_reply_to_account_id = account_id))' # rubocop:disable Naming/VariableNumber
  end

  def down
    add_index :statuses, [:id, :language, :account_id], name: :index_statuses_public_20250129, algorithm: :concurrently, order: { id: :desc }, where: 'deleted_at IS NULL AND visibility = 0 AND reblog_of_id IS NULL AND ((NOT reply) OR (in_reply_to_account_id = account_id))' # rubocop:disable Naming/VariableNumber
  end
end
