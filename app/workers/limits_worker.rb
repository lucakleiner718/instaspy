class LimitsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical

  def perform
    total_remaining = 0
    logins = 0
    InstagramAccount.all.each do |account|
      logins += account.logins.size
      account.logins.each do |login|
        resp = nil

        begin
          client = InstaClient.new(login).client
          resp = client.utils_raw_response
        rescue => e
        end

        if resp.present?
          total_remaining += resp.headers[:x_ratelimit_remaining].to_i
        end
      end
    end

    total_limit = logins * 5_000

    s = Stat.where(key: 'ig_limit').first_or_initialize
    s.value = { total_limit: total_limit, total_remaining: total_remaining }.to_json
    s.save
  end
end