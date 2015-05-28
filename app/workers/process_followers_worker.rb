class ProcessFollowersWorker
  include Sidekiq::Worker

  sidekiq_options queue: :low, retry: true

  def perform origin_id, resp
    origin = User.find(origin_id)

    users = User.in(insta_id: resp['data'].map{|el| el['id']})
    fols = Follower.where(user_id: origin.id).in(follower_id: users.map{|el| el.id})

    resp['data'].each do |user_data|
      new_record = false

      user = users.select{|el| el.insta_id == user_data['id'].to_i}.first
      unless user
        user = User.new insta_id: user_data['id']
        new_record = true
      end

      if user.insta_id.present? && user_data['id'].present? && user.insta_id != user_data['id'].to_i
        raise Exception
      end
      user.set_data user_data

      user.must_save if user.changed?

      if new_record
        Follower.create(user_id: origin.id, follower_id: user.id)
      else
        fol = Follower.where(user_id: origin.id, follower_id: user.id)

        fol_exists = fols.select{|el| el.follower_id == user.id }.first

        if !fol_exists
          fol = fol.first_or_initialize
          if fol.new_record?
            fol.save
          end
        end
      end
    end
  end

  def self.spawn origin_id
    origin = User.find(origin_id)
    return false if origin.insta_id.blank?

    next_cursor = nil

    origin.update_info!

    return false if origin.destroyed? || origin.private?

    while true
      retries = 0
      begin
        client = InstaClient.new.client
        resp = client.user_followed_by origin.insta_id, cursor: next_cursor, count: 100
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::BadRequest,
        Instagram::InternalServerError,
        JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
        sleep 30
        retries += 1
        retry if retries <= 5
      end

      ProcessFollowersWorker.perform_async origin.id, resp

      next_cursor = resp.pagination['next_cursor']

      break unless next_cursor
    end
  end
end