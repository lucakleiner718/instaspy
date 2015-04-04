class InstagramAccount < ActiveRecord::Base

  has_many :logins, class_name: 'InstagramLogin', foreign_key: :account_id
  
end
