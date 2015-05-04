class TrackUser

  include Mongoid::Document
  field :followees, type: Boolean, default: false
  field :followers, type: Boolean, default: false
  include Mongoid::Timestamps

  belongs_to :user

  index({ user_id: 1 }, { drop_dups: true })

end
