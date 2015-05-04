class InstagramLogin

  include Mongoid::Document
  field :account_id, type: Integer
  field :ig_id, type: Integer
  field :access_token, type: String
  include Mongoid::Timestamps

  index({ account_id: 1, ig_id: 1 }, { unique: true })

  belongs_to :account, class_name: 'InstagramAccount'
  belongs_to :user, foreign_key: :ig_id, primary_key: :insta_id

end
