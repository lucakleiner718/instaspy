require 'rails_helper'

RSpec.describe User, type: :model do

  before :all do
    create(:instagram_login) if InstagramLogin.all.size == 0
  end

  it 'should add new user to database' do
    expect(User.where(username: 'anton_zaytsev').size).to eq 0

    VCR.use_cassette("user_anton_zaytsev") do
      user = User.get('anton_zaytsev')
    end

    expect(User.where(username: 'anton_zaytsev').size).to eq 1
  end

  it 'should reject wrong username' do
    expect(User.get('wrong-username')).to be_falsey
    expect(User.get('1234567890123456789012345678901')).to be_falsey
    expect(User.get('')).to be_falsey
    expect(User.get(nil)).to be_falsey
    expect(User.get(' ')).to be_falsey
    expect(User.get(000000)).to be_falsey
  end

  it 'should return recent media' do
    user = User.get('shopbop')
    expect(Media.where(user_id: user.id).size).to eq 0
    VCR.use_cassette('user_shopbop_recent_media_50') do
      user.recent_media total_limit: 50
    end
    expect(Media.where(user_id: user.id).size).to be > 50
  end

  it 'should update user' do
    user = User.create(username: 'shopbop')
    expect(user.grabbed_at).to be_nil

    VCR.use_cassette('user_shopbop') do
      user.update_info!
    end
    expect(user.insta_id).to eq 10526532
    expect(user.grabbed_at).to_not be_nil
    expect(user.followed_by).to_not be_nil
    expect(user.follows).to_not be_nil
    expect(user.website).to_not be_nil
    expect(user.bio).to_not be_nil
    expect(user.full_name).to_not be_nil
    expect(user.username).to_not be_nil
  end

  it "should force update user's info" do
    user = User.create(username: 'shopbop')

    VCR.use_cassette('user_shopbop') do
      user.update_info!
    end

    user.full_name = 'test'

    VCR.use_cassette('user_shopbop') do
      user.update_info!
    end

    expect(user.full_name).to eq 'test'

    VCR.use_cassette('user_shopbop') do
      user.update_info! force: true
    end

    expect(user.full_name).to eq 'Shopbop'
  end

  it 'should update info even for private user' do
    user = User.create(insta_id: 143930449, username: 'ylenialabate')
    VCR.use_cassette('user_143930449') do
      user.update_info!
    end

    expect(user.private).to be_truthy
    expect(user.media_amount).to_not be_nil
    expect(user.follows).to_not be_nil
    expect(user.followed_by).to_not be_nil
    expect(user.full_name).to_not be_nil
  end

  it 'should add by insta_id' do
    user = User.create(insta_id: 1446641248)
    expect(user.username).to be_nil
    VCR.use_cassette('user_1446641248') do
      user.update_info!
    end
    expect(user.username).to_not be_nil
    expect(user.insta_id).to eq 1446641248
    expect(user.grabbed_at).to_not be_nil
    expect(user.followed_by).to_not be_nil
    expect(user.follows).to_not be_nil
    expect(user.website).to_not be_nil
    expect(user.bio).to_not be_nil
    expect(user.full_name).to_not be_nil
    expect(user.username).to_not be_nil
  end

  it 'should update followers' do
    user = User.create(insta_id: 1446641248)
    expect(user.followers.size).to eq 0
    VCR.use_cassette('user_1446641248_followers') do
      user.update_followers
    end
    user.followers.reload
    expect(user.followers.size).to eq 70
  end

  it 'should catch email from bio' do
    user = create(:user_with_email)
    expect(user.email).to eq 'email@gmail.com'
  end

  it 'should update location!' do

  end

end
