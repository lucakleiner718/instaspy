class InstaClient

  def initialize account=nil
    @account = account || InstagramAccount.where('access_token is not null').sample

    Instagram.configure do |config|
      config.client_id = @account.client_id
      config.client_secret = @account.client_secret
      config.no_response_wrapper = true
    end

    @client = Instagram.client(access_token: @account.access_token) if @account.access_token.present?
  end

  def account
    @account
  end

  def client
    @client
  end

  def self.subscriber
    account = InstagramAccount.where('access_token is not null').order(created_at: :desc).first
    client = self.new(account)
    client.client
  end

  def self.subscribe_tag tag
    self.subscriber.create_subscription object: :tag, callback_url: 'http://94.137.22.246:3005/tag_media/added', aspect: :media, object_id: tag, verify_token: 'text1'
  end

end