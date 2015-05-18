require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe Media, type: :model do
  before :each do
    create(:instagram_login) if InstagramLogin.all.size == 0
  end

  it 'should start worker' do
    expect {
      UserFollowersWorker.perform_async('user_id', {param: 1})
    }.to change(UserFollowersWorker.jobs, :size).by(1)

    expect {
      UserFollowersWorker.perform_async('user_id2', param: 1)
    }.to change(UserFollowersWorker.jobs, :size).by(1)
  end

end
