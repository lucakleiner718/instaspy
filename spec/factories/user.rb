FactoryGirl.define do
  factory :user1, class: User do
    insta_id 891079859
    username "beth__winter"
    full_nam "Beth            chlo"
    bio ""
    website ""
    follows 1863
    followed_by 1001
    media_amount 10
    private false
    grabbed_at "2015-04-16 03:48:29"
    created_at "2015-04-16 03:43:15"
    updated_at "2015-04-17 10:11:12"
    email nil
    location_country nil
    location_state nil
    location_city nil
    location_updated_at nil
    avg_likes 32
    avg_likes_updated_at "2015-04-17 10:11:12"
    avg_comments 4
    avg_comments_updated_at "2015-04-17 10:11:12"
  end
end