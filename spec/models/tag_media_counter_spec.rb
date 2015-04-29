require 'rails_helper'

RSpec.describe TagMediaCounter, type: :model do

  it 'should increment tag media amount' do
    tag = Tag.get('shopbop')
    expect(tag.media_count).to eq 0
    Tag.increment_counter tag.id
    expect(tag.media_count).to eq 1
  end

  it 'should decrement tag media amount' do
    tag = Tag.get('shopbop')
    expect(tag.media_count).to eq 0
    Tag.decrement_counter tag.id
    expect(tag.media_count).to eq -1
  end

end
