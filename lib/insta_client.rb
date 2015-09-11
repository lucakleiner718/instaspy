class InstaClient

  def initialize login=nil
    set_login login
    set_client
    build_client
  end

  def account
    @login.account
  end

  def ig_client
    @ig_client
  end

  def build_client
    @client_proxy = Client.new self
  end

  def set_login login
    @login = login
    # if !@login && $insta_client_login
    #   @login = $insta_client_login
    #   # Rails.logger.debug "I use loaded login #{@login.id}".green
    # else
    #   @login = login || InstagramLogin.all.sample
    #   $insta_client_login = @login if $insta_client_login.blank? || $insta_client_login.id != @login.id
    #   # Rails.logger.debug "I use new login #{@login.id}".cyan
    # end
    if !@login
      @login = InstagramLogin.all.sample
    end

    raise unless @login
  end

  def set_client
    @ig_client = Instagram.client access_token: @login.access_token,
                client_id: @login.account.client_id,
                client_secret: @login.account.client_secret,
                no_response_wrapper: true
  end

  def login
    @login
  end

  def client direct: false
    direct ? @ig_client : @client_proxy
  end

  def change_login!
    @login = (@login ? InstagramLogin.where('id != ?', @login.id) : InstagramLogin.all).sample
    set_client
    # $insta_client_login = @login
  end

  def invalid_login!
    @login.destroy rescue
    change_login!
  end

  # def self.subscriber
  #   account = InstagramAccount.where('access_token is not null').order(created_at: :desc).first
  #   client = self.new(account)
  #   client.client
  # end

  # def self.subscribe_tag tag
  #   self.subscriber.create_subscription object: :tag, callback_url: 'http://94.137.22.246:3005/tag_media/added', aspect: :media, object_id: tag, verify_token: 'text1'
  # end

  class Client

    def initialize ic
      @ic = ic
    end

    def method_missing(method, *args, &block)
      retries = 0
      retries_limit = 3

      begin
        @ic.ig_client.send(method, *args, &block)
      rescue Instagram::TooManyRequests => e
        Rails.logger.info "#{">> issue".red} #{e.class.name} :: #{e.message}"
        @ic.change_login!
        sleep 10*retries
        retries += 1
        retry if retries < retries_limit
        raise e
      rescue Instagram::ServiceUnavailable, Instagram::BadGateway, Instagram::InternalServerError, Instagram::GatewayTimeout,
        JSON::ParserError,
        Faraday::ConnectionFailed, Faraday::SSLError, Faraday::ParsingError, Faraday::TimeoutError,
        Zlib::BufError,
        Errno::EPIPE, Errno::EOPNOTSUPP, Errno::ETIMEDOUT => e

        Rails.logger.info "#{">> issue".red} #{e.class.name} :: #{e.message}"
        sleep 10*retries
        retries += 1
        retry if retries < retries_limit
        raise e
      rescue Instagram::BadRequest => e
        Rails.logger.info "#{">> issue".red} #{e.class.name} :: #{e.message}"
        if e.message =~ /The access_token provided is invalid/
          @ic.invalid_login!
          retry
        else
          raise e
        end
      end
    end

  end

end