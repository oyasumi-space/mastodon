# frozen_string_literal: true

require 'rails_helper'

RSpec.describe REST::CustomEmojiSerializer do
  subject { serialized_record_json(record, described_class) }

  let(:record) { Fabricate.build :custom_emoji, id: 123, category: Fabricate(:custom_emoji_category, name: 'Category Name'), aliases: aliases }
  let(:aliases) { [] }

  describe 'serialization' do
    it 'returns expected values' do
      expect(subject)
        .to include(
          'category' => be_a(String).and(eq('Category Name')),
          'aliases' => be_a(Array).and(eq([]))
        )
    end
  end

  context 'when null aliases' do
    let(:aliases) { nil }

    it 'returns normalized aliases' do
      expect(subject['aliases']).to eq []
    end
  end

  context 'when aliases contains null' do
    let(:aliases) { [nil] }

    it 'returns normalized aliases' do
      expect(subject['aliases']).to eq []
    end
  end

  context 'when aliases contains normal text' do
    let(:aliases) { ['neko'] }

    it 'returns normalized aliases' do
      expect(subject['aliases']).to eq ['neko']
    end
  end
end
