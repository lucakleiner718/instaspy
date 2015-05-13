FactoryGirl.define do
  factory :shopbop do
    name 'shopbop'
  end

  sequence :tag do |n|
    "sequencetag#{n}"
  end
end
