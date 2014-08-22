ENV['CLIENT_ID'] = '910380fe0780405f9d51ababaf69dd32'
ENV['CLIENT_SECRET'] = '372e8e4eea29468cbc533b3e389dcc66'
ENV['WEBSITE_URL'] = 'http://localhost:3000'
ENV['REDIRECT_URI'] = 'http://localhost:3000/oauth/signin'

Instagram.configure do |config|
  config.client_id = ENV['CLIENT_ID']
  config.client_secret = ENV['CLIENT_SECRET']
end