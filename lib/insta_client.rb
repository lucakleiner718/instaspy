class InstaClient

  def initialize index=nil
    if index
      @index = index
    else
      size = Rails.application.secrets.instagram_client_id.size
      @index = rand(size)
    end

    Instagram.configure do |config|
      config.client_id = Rails.application.secrets.instagram_client_id[index]
      config.client_secret = Rails.application.secrets.instagram_client_secret[index]
      config.no_response_wrapper = true
    end

    @client = Instagram.client(access_token: Setting.g(Rails.application.secrets.instagram_client_id[index]))
  end

  def index
    @index
  end

  def client
    @client
  end

end