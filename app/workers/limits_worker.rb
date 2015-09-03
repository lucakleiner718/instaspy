class LimitsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical, unique: true

  def perform
    total_remaining = 0
    logins = 0
    InstagramAccount.all.each do |account|
      account.logins.each do |login|
        resp = nil

        begin
          ic = InstaClient.new(login)
          resp = ic.client.utils_raw_response
        rescue Instagram::InternalServerError => e
          next
        end

        if resp.present?
          total_remaining += resp.headers[:x_ratelimit_remaining].to_i
        end
      end

      logins += InstagramLogin.where(account_id: account.id).size
    end

    total_limit = logins * 5_000

    s = Stat.where(key: 'ig_limit').first_or_initialize
    s.value = { total_limit: total_limit, total_remaining: total_remaining }.to_json
    s.save
  end
end