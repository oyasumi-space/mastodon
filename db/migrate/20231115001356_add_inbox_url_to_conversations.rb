# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddInboxURLToConversations < ActiveRecord::Migration[7.1]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def change
    safety_assured do
      add_column :conversations, :inbox_url, :string, default: nil, null: true
      add_column :conversations, :ancestor_status_id, :bigint, default: nil, null: true
    end
  end
end
