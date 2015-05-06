require 'rails_helper'

RSpec.describe Media, type: :model do

  before :each do
    create(:instagram_login) if InstagramLogin.all.size == 0
  end

  # it "should increment tags media_count after tag added to media" do
  #   # user = FactoryGirl.create(:user1)
  #   media = FactoryGirl.create(:media_first)
  #
  #   media.media_tags ['shopbop', 'tag2']
  #
  #   expect(media.tags.size).to eq(2)
  #
  #   expect(Tag.get('shopbop').media_count).to eq(1)
  #   expect(Tag.get('tag2').media_count).to eq(1)
  #   expect(Tag.get('tag1').media_count).to eq(0)
  # end

  it "should update media" do
    media = FactoryGirl.create(:media2)
    VCR.use_cassette("media_#{media.insta_id}") do
      media.update_info!
    end

    expect(media.created_time).to_not be_nil
    expect(media.created_at).to_not be_nil
    expect(media.updated_at).to_not be_nil
    expect(media.user_id).to_not be_nil
    expect(media.likes_amount).to_not be_nil
    expect(media.comments_amount).to_not be_nil
    expect(media.link).to_not be_nil
    expect(media.location_city).to be_nil
    expect(media.location_state).to be_nil
    expect(media.location_country).to be_nil

    if media.location_present?
      expect(media.location_lat).to_not be_nil
      expect(media.location_lng).to_not be_nil
    else
      expect(media.location_lat).to be_nil
      expect(media.location_lng).to be_nil
    end
  end

  it "should update location" do
    media = FactoryGirl.create(:media_location)
    VCR.use_cassette("media_#{media.insta_id}_location") do
      media.update_location!
    end

    expect(['US', 'United States']).to include media.location_country
    expect(['FL', 'Florida']).to include media.location_state
    expect(['Hollywood', 'Broward']).to include media.location_city
  end

  it "should return media" do
    media = FactoryGirl.create(:media2)
    expect(Media.get(media.insta_id).id).to eq media.id
  end

end
