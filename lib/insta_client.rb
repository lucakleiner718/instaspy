class InstaClient

  def initialize login=nil
    @login = login || InstagramLogin.joins(:account).sample

    raise unless @login

    Instagram.configure do |config|
      config.client_id = @login.account.client_id
      config.client_secret = @login.account.client_secret
      config.no_response_wrapper = true
    end

    @client = Instagram.client(access_token: @login.access_token)
  end

  def account
    @login.account
  end

  def login
    @login
  end

  def client
    @client
  end

  # def self.subscriber
  #   account = InstagramAccount.where('access_token is not null').order(created_at: :desc).first
  #   client = self.new(account)
  #   client.client
  # end

  # def self.subscribe_tag tag
  #   self.subscriber.create_subscription object: :tag, callback_url: 'http://94.137.22.246:3005/tag_media/added', aspect: :media, object_id: tag, verify_token: 'text1'
  # end

end