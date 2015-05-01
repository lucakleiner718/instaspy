class Follower

  include Mongoid::Document

  belongs_to :user, class_name: 'User', foreign_key: :user_id
  belongs_to :follower, class_name: 'User', foreign_key: :follower_id
  belongs_to :followee, class_name: 'User', foreign_key: :user_id

  #   t.integer  "user_id"
  #   t.integer  "follower_id"
  #   t.datetime "created_at"
  #   t.datetime "followed_at"
  # end
  #
  # add_index "followers", ["followed_at"], name: "index_followers_on_followed_at", using: :btree
  # add_index "followers", ["follower_id"], name: "index_followers_on_follower_id", using: :btree
  # add_index "followers", ["user_id"], name: "index_followers_on_user_id", using: :btree



end
