class TrackUser

  include Mongoid::Document
  field :followees, type: Boolean, default: false
  field :followers, type: Boolean, default: false
  include Mongoid::Timestamps

  belongs_to :user

  add_index "track_users", ["user_id"], name: "index_track_users_on_user_id", unique: true, using: :btree

end
