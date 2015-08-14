class UserFollowersWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id, *args
    options = args.extract_options!
    options.symbolize_keys!

    user = User.find(user_id)

    if !options[:batch] && options[:ignore_batch]
      options.delete(:ignore_batch)
      options.delete(:batch)
      user.update_followers *args, options
    else
      batch_update user, *args, options
    end
  end

  private

  def batch_update user, *args
    user.update_info! force: true

    if user.followed_by < 2_000
      UserFollowersWorker.perform_async user.id, ignore_batch: true
      return true
    end

    speed = nil
    if user.user_followers.where("followed_at is not null").size > 2
      speed = user.follow_speed
    end

    speed = 2_000 if !speed || speed > 2_000

    start = Time.now.to_i
    amount = (user.followed_by/1_000).ceil
    amount.times do |i|
      start_cursor = start-i*speed*100
      next if start_cursor < 0
      finish_cursor = i+1 < amount ? start-(i+1)*speed*100 : nil
      UserFollowersWorker.perform_async(user.id, start_cursor: start_cursor, finish_cursor: finish_cursor, ignore_exists: true, ignore_batch: true)
    end
  end
end