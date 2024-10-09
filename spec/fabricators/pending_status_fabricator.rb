# frozen_string_literal: true

Fabricator(:pending_status) do
  account { Fabricate.build(:account) }
  fetch_account { Fabricate.build(:account) }
  uri { sequence(:uri) { |i| "https://example.com/note-#{i}" } }
end
