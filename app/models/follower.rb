class Follower < ActiveRecord::Base

  belongs_to :user, class_name: 'User', foreign_key: :user_id
  belongs_to :follower, class_name: 'User', foreign_key: :follower_id
  belongs_to :followee, class_name: 'User', foreign_key: :user_id

end
