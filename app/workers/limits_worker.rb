class LimitsWorker
  include Sidekiq::Worker

  def perform
    total_remining = 0
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
        total_remining +=resp.headers[:x_ratelimit_remaining].to_i
      end
    end

    s = Stat.where(key: 'ig_limit').first_or_initialize
    s.value = { total_limit: total_limit, total_remining: total_remining }.to_json
    s.save
  end
end