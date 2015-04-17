FactoryGirl.define do
  factory :instagram_account, class: InstagramAccount do
    # id 1
    client_id '1580f11e7be6444cbb6e941dcd7b8c6c'
    client_secret '43662ac3db0143ccb83385f783bff770'
    redirect_uri 'http://107.170.110.156/oauth/signin'
  end
end

FactoryGirl.define do
  factory :instagram_login, class: InstagramLogin do
    association :account, factory: :instagram_account
    ig_id 35938880
    access_token '35938880.1580f11.53c87da9327c4ea7bff07a2cea3602ca'
  end
end