require 'rails_helper'

RSpec.describe Tag, type: :model do

  before :each do
    create(:instagram_login) if InstagramLogin.all.size == 0
  end

  it 'should return tag entry' do
    expect(Tag.get('shopbop').name).to eq 'shopbop'
  end

  it 'should return recent media' do
    tag = Tag.get('shopbop')
    expect(tag.media.size).to eq 0

    VCR.use_cassette('tag_shopbop_recent_media_50') do
      tag.recent_media total_limit: 50
    end

    tag.reload

    expect(tag.media.size).to be > 50
    media = tag.media.first
    expect(media.tag_names).to eq media.tags.map(&:name)
  end

  it 'should add to csv report' do
    expect(Tag.where(name: 'shopbop').size).to eq 0
    Tag.add_to_csv('shopbop')
    expect(Tag.get('shopbop').observed_tag).to_not be_nil
    expect(Tag.get('shopbop').observed_tag.export_csv).to be_truthy
    expect(Tag.get('shopbop').observed_tag.for_chart).to be_falsey
  end

  it 'should remove from csv report' do
    Tag.add_to_csv('shopbop')
    Tag.remove_from_csv('shopbop')
    expect(Tag.get('shopbop').observed_tag).to_not be_nil
    expect(Tag.get('shopbop').observed_tag.export_csv).to be_falsey
    expect(Tag.get('shopbop').observed_tag.for_chart).to be_falsey
  end

  # it 'should remove from csv report if have other observed booleans' do
  #   Tag.add_to_csv('shopbop')
  #   Tag.get('shopbop').observed_tag.update_attribute :for_chart, true
  #   expect(Tag.get('shopbop').observed_tag.for_chart).to be_truthy
  #   Tag.remove_from_csv('shopbop')
  #   expect(Tag.get('shopbop').observed_tag.for_chart).to be_falsey
  # end

  it 'should have lower name' do
    tag = Tag.create name: 'TEST'
    expect(tag.name).to eq 'test'
  end

  it 'should find only downcase' do
    Tag.create name: 'TEST'
    expect(Tag.where(name: 'test').size).to eq 1
    expect(Tag.where(name: 'TEST').size).to eq 0
  end

end
