# frozen_string_literal: true

class RemoveKmyblueQuoteAccessories < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_column :custom_filters, :with_quote, :boolean, default: true, null: false
      remove_column :status_references, :quote, :boolean, default: false, null: false
    end
  end
end
