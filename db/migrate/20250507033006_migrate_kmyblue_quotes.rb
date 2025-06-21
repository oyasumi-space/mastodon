# frozen_string_literal: true

class MigrateKmyblueQuotes < ActiveRecord::Migration[8.0]
  class Status < ApplicationRecord; end
  class Quote < ApplicationRecord; end

  def up
    ActiveRecord::Base.transaction do
      Status.where.not(quote_of_id: nil).select(:id, :quote_of_id, :account_id).in_batches do |owner_statuses|
        quoted_statuses = Status.where(id: owner_statuses.pluck(:quote_of_id)).select(:id, :account_id)

        owner_statuses.each do |owner_status|
          quoted_status = quoted_statuses.detect { |status| status.id == owner_status.quote_of_id }
          next unless quoted_status

          begin
            Quote.create!(
              status_id: owner_status.id,
              quoted_status_id: owner_status.quote_of_id,
              state: 1,
              account_id: owner_status.account_id,
              quoted_account_id: quoted_status.account_id
            )
          rescue
            # duplicate of snowflake
          end
        end
      end
    end
  end

  def down
    Quote.select(:quoted_status_id, :status_id).in_batches do |quotes|
      statuses = Status.where(id: quotes.pluck(:status_id))
      quotes.each do |quote|
        status = statuses.detect { |s| s.id == quote.status_id }
        next unless status

        status.update!(quote_of_id: quote.quoted_status_id)
      end
    end
  end
end
