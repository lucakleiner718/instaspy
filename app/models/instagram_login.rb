class InstagramLogin

  include Mongoid::Document
  field :ig_id, type: Integer
  field :access_token, type: String
  include Mongoid::Timestamps

  belongs_to :account, class_name: 'InstagramAccount'
  belongs_to :user, foreign_key: :ig_id, primary_key: :insta_id

  index({ account_id: 1, ig_id: 1 }, { unique: true })

end
