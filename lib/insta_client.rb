class InstaClient

  def initialize login=nil
    if $insta_client_login
      @login = $insta_client_login
      # Rails.logger.debug "I use loaded login #{@login.id}".green
    else
      @login = login || InstagramLogin.all.sample
      $insta_client_login = @login if $insta_client_login.blank? || $insta_client_login.id != @login.id
      # Rails.logger.debug "I use new login #{@login.id}".cyan
    end

    raise unless @login

    @client = Instagram.client access_token: @login.access_token,
                               client_id: @login.account.client_id,
                               client_secret: @login.account.client_secret,
                               no_response_wrapper: true
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

  def change_login!
    @login = (@login ? InstagramLogin.where('id != ?', @login.id) : InstagramLogin.all).sample
    $insta_client_login = @login
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

end