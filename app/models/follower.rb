class Follower

  include Mongoid::Document

  belongs_to :user, class_name: 'User', foreign_key: :user_id
  belongs_to :follower, class_name: 'User', foreign_key: :follower_id
  belongs_to :followee, class_name: 'User', foreign_key: :user_id
  field :followed_at, type: DateTime

  include Mongoid::Timestamps::Created

  index({ user_id: 1, follower_id: 1}, { drop_dups: true })
  index followed_at: 1
  index follower_id: 1
  index user_id: 1

end
