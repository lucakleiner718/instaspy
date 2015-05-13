class TrackUser

  include Mongoid::Document
  belongs_to :user
  field :followees, type: Boolean, default: false
  field :followers, type: Boolean, default: false
  include Mongoid::Timestamps::Updated

  index({ user_id: 1 }, { drop_dups: true })

end
