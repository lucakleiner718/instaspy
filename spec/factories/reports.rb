FactoryGirl.define do
  factory :report_followers, class: Report do
    format 'followers'
    input 'shopbop'
    notify_email 'test@mail.com'
  end
end
