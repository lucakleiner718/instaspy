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

end