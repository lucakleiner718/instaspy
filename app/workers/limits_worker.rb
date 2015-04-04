class LimitsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical

  def perform
    total_remaining = 0
    total_limit = 0
    ig_accounts = InstagramAccount.all
    ig_accounts.each do |account|
      resp = nil
      begin
        client = InstaClient.new(account).client
        resp = client.utils_raw_response
      rescue => e
      end
      if resp.present?
        total_limit += resp.headers[:x_ratelimit_limit].to_i
        total_remaining +=resp.headers[:x_ratelimit_remaining].to_i
      end
    end

    total_limit = ig_accounts.size * 5_000 if total_limit == 0

    s = Stat.where(key: 'ig_limit').first_or_initialize
    s.value = { total_limit: total_limit, total_remaining: total_remaining }.to_json
  end
end