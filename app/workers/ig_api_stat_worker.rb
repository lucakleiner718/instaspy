class IgApiStatWorker

  include Sidekiq::Worker

  def perform
    total_limit = 0
    accounts = InstagramAccount.all
    accounts.each do |account|
      begin
        ic = InstaClient.new(account)
        resp = ic.client.utils_raw_response
        total_limit += resp.headers[:x_ratelimit_remaining].to_i
      rescue => e
      end
    end

    Stat.create key: 'ig_api_stat', value: {limit: total_limit, accounts: accounts.size}, created_at: Time.now.utc
  end
end