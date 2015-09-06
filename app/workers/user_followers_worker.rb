class UserFollowersWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, unique_args: -> (args) {
      if args[1] && (args[1][:start_cursor] || args[1]['start_cursor'])
        args
      else
        [ args.first ]
      end
    }

  def perform user_id, *args
    options = args.extract_options!
    options.symbolize_keys!

    user = User.find(user_id)

    user.update_info! unless user.followed_by

    return false if user.private? || user.followers_size >= user.followed_by

    if options[:ignore_batch] && !options[:batch]
      options.delete(:ignore_batch)
      options.delete(:batch)
      UserUpdateFollowers.perform user: user, options: options
    else
      batch_collect user, *args, options
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

  def self.get_jobs user_id
    jobs = []
    queue_jobs = Sidekiq::Queue.new(UserFollowersWorker.sidekiq_options['queue'])
    queue_jobs.each do |job|
      if job.klass == 'UserFollowersWorker' && job.args[0].to_i == user_id.to_i
        jobs << job
      end
    end
    jobs
  end

  def batch_collect user, *args
    options = args.extract_options!
    return if UserFollowersWorker.jobs_exists?(user.id) && !options[:force_batch]

    user.update_info! force: true

    return if user.followers_size >= user.followed_by

    if user.followed_by < 2_000
      UserFollowersWorker.perform_async user.id, ignore_batch: true
      return true
    end

    beginning = DateTime.parse('2010-09-01')
    start = Time.now.to_i
    seconds_since_start = start - beginning.to_i
    worker_days = 10.days
    amount = (seconds_since_start/worker_days.to_f).ceil

    amount.times do |i|
      offset = i*worker_days
      start_cursor = i > 0 ? start - offset : nil
      break if start_cursor && start_cursor < 0
      finish_cursor = i+1 < amount ? start-(i+1)*worker_days : nil
      UserFollowersWorker.perform_async(user.id, start_cursor: start_cursor, finish_cursor: finish_cursor, ignore_exists: true, ignore_batch: true)
    end
  end

  def self.jobs_exists? user_id
    exists = false
    queue_jobs = Sidekiq::Queue.new(UserFollowersWorker.sidekiq_options['queue'])
    queue_jobs.each do |job|
      if job.klass == 'UserFollowersWorker' && job.args[0].to_i == user_id.to_i
        exists = true
        break
      end
    end

    unless exists
      workers = Sidekiq::Workers.new
      workers.each do |process_id, thread_id, work|
        if work['payload']['class'] == 'UserFollowersWorker' && work['payload']['args'][0].to_i == user_id.to_i
          if work['payload']['args'][1] && work['payload']['args'][1]['ignore_batch']
            exists = true
            break
          end
        end
      end
    end

    exists
  end

end