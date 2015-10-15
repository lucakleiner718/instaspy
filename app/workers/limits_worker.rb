class LimitsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical, unique: :until_executed

  TOKEN_LIMIT = 5_000

  def perform
    total_remaining = 0
    logins = 0
    InstagramAccount.all.each do |account|
      account.logins.each do |login|
        resp = nil

        begin
          ic = InstaClient.new(login)
          resp = ic.client.utils_raw_response
          logins += 1
        rescue Instagram::InternalServerError => e
          next
        rescue Instagram::BadRequest => e
          if e.message =~ /The access_token provided is invalid/
            ic.invalid_login!
            retry
          else
            raise e
          end
        end

        if resp.present?
          total_remaining += resp.headers[:x_ratelimit_remaining].to_i
        end
      end
    end

    total_limit = logins * TOKEN_LIMIT

    s = Stat.where(key: 'ig_limit').first_or_initialize
    s.value = { total_limit: total_limit, total_remaining: total_remaining }.to_json
    s.save
  end
end