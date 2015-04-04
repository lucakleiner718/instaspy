class InstagramLogin < ActiveRecord::Base
  belongs_to :account, class_name: 'InstagramAccount'
  belongs_to :user, foreign_key: :ig_id, primary_key: :insta_id
end
