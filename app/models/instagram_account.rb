class InstagramAccount

  include Mongoid::Document
  field :client_id, type: String
  field :client_secret, type: String
  field :redirect_uri, type: String
  field :login_process, type: Boolean
  include Mongoid::Timestamps

  index({client_id: 1}, { unique: true })

  has_many :logins, class_name: 'InstagramLogin', foreign_key: :account_id

end
