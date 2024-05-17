# frozen_string_literal: true

Fabricator(:instance_info) do
  domain { sequence(:domain) { |i| "info-#{i}.example.com" } }
  software 'mastodon'
  version '4.1.0'
end
