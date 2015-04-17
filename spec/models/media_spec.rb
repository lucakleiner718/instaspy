require 'rails_helper'

RSpec.describe Media, type: :model do

  before :all do
    FactoryGirl.create(:instagram_login) if InstagramLogin.all.size == 0
  end

  it "should increment tags media_count after tag added to media" do
    # user = FactoryGirl.create(:user1)
    media = FactoryGirl.create(:media_first)

    media.media_tags ['shopbop', 'tag2']

    expect(media.tags.size).to eq(2)

    expect(Tag.get('shopbop').media_count).to eq(1)
    expect(Tag.get('tag2').media_count).to eq(1)
    expect(Tag.get('tag1').media_count).to eq(0)
  end

  it "should update media" do
    media = FactoryGirl.create(:media2)
    media.update_info!

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

end
