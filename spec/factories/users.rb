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

  factory :user_with_email, class: User do
    insta_id 89107985911
    username "beth__winter2"
    bio "This is just my account email@gmail.com | 123"
  end

  factory :outdated, class: User do
    insta_id 89107985937
    username "beth__winter1"
    bio "This is just my account email@gmail.com | 123"
    grabbed_at nil
  end

  factory :outdated2, class: User do
    insta_id 89107985924
    username "beth__winter13"
    bio "This is just my account email@gmail.com | 123"
    grabbed_at 10.days.ago
  end

  factory :recently_grabbed, class: User do
    insta_id 89107985935
    username "beth__winter24"
    bio "This is just my account email@gmail.com | 123"
    grabbed_at 1.day.ago
  end
end