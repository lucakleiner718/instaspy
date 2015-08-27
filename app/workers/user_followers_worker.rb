class UserFollowersWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, unique_args: -> (args) {
      if args[1] && args[1][:start_cursor]
        args
      else
        [ args.first ]
      end
    }

  def perform user_id, *args
    options = args.extract_options!
    options.symbolize_keys!

    user = User.find(user_id)

    return false if jobs_exists? (user.id) || user.followers_size >= user.followed_by

    if !options[:batch] && options[:ignore_batch]
      options.delete(:ignore_batch)
      options.delete(:batch)
      user.update_followers *args, options
    else
      batch_update user, *args, options
    end
  end

  def self.delete_exists_jobs user_id
    queue_jobs = Sidekiq::Queue.new(UserFollowersWorker.sidekiq_options['queue'])
    queue_jobs.each do |job|
      if job.klass == 'UserFollowersWorker' && job.args[0].to_i == user_id.to_i
        job.delete
      end
    end
  end

  private

  def batch_update user, *args
    user.update_info! force: true

    return false if user.followers_size >= user.followed_by

    if user.followed_by < 2_000
      UserFollowersWorker.perform_async user.id, ignore_batch: true
      return true
    end

    follow_speed = 1_000

    start = Time.now.to_i
    amount = (user.followed_by/1_000).ceil
    amount.times do |i|
      start_cursor = start-i*follow_speed*100
      next if start_cursor < 0
      finish_cursor = i+1 < amount ? start-(i+1)*follow_speed*100 : nil
      UserFollowersWorker.perform_async(user.id, start_cursor: start_cursor, finish_cursor: finish_cursor, ignore_exists: true, ignore_batch: true)
    end
  end

  def jobs_exists? user_id
    exists = false
    queue_jobs = Sidekiq::Queue.new(UserFollowersWorker.sidekiq_options['queue'])
    queue_jobs.each do |job|
      if job.klass == 'UserFollowersWorker' && job.args[0].to_i == user_id.to_i
        exists = true
        return
      end
    end
    exists
  end
end