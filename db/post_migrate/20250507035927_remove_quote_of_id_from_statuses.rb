# frozen_string_literal: true

class RemoveQuoteOfIdFromStatuses < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_column :statuses, :quote_of_id, :bigint, default: nil, null: true
    end
  end
end
