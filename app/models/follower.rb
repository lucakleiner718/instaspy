class Follower

  include Mongoid::Document

  belongs_to :user, class_name: 'User', foreign_key: :user_id
  belongs_to :follower, class_name: 'User', foreign_key: :follower_id
  belongs_to :followee, class_name: 'User', foreign_key: :user_id

  include Mongoid::Timestamps

  index followed_at: 1
  index follower_id: 1
  index user_id: 1

end
