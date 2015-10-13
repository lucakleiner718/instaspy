class UserFollowersCollectWorker

  include Sidekiq::Worker
  sidekiq_options unique: :until_and_while_executing, unique_args: -> (args) {
      if args[1] && (args[1][:start_cursor] || args[1]['start_cursor'] || args[1][:finish_cursor] || args[1]['finish_cursor'] || args[1][:ignore_uniqueness] || args[1]['ignore_uniqueness'])
        args
      else
        [ args.first ]
      end
    }

  def perform user_id, *args
    options = args.extract_options!
    options.symbolize_keys!

    begin
      user = User.find(user_id)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.debug e.message
      return false
    end

    user.update_info! unless user.followed_by

    present_ratio = user.followers_size / user.followed_by.to_f

    return false if user.private? || (user.followers_size >= user.followed_by && present_ratio < 1.2)

    if (options[:ignore_batch] && !options[:batch]) || user.followed_by < 2_000 || present_ratio > 1.2
      options.delete(:ignore_batch)
      options.delete(:batch)
      UserFollowersCollect.perform user: user, options: options
    else
      batch_collect user, *args, options
    end
  end

  def self.delete_exists_jobs user_id
    queue_jobs = Sidekiq::Queue.new(UserFollowersCollectWorker.sidekiq_options['queue'])
    queue_jobs.each do |job|
      if job.klass == UserFollowersCollectWorker.name && job.args[0].to_i == user_id.to_i
        job.delete
      end
    end
  end

  def self.get_jobs user_id
    jobs = []
    queue_jobs = Sidekiq::Queue.new(UserFollowersCollectWorker.sidekiq_options['queue'])
    queue_jobs.each do |job|
      if job.klass == UserFollowersCollectWorker.name && job.args[0].to_i == user_id.to_i
        jobs << job
      end
    end
    jobs
  end

  def batch_collect user, *args
    options = args.extract_options!
    return if UserFollowersCollectWorker.jobs_exists?(user.id) && !options[:force_batch]

    user.update_info! force: true

    return if user.followers_size >= user.followed_by

    if user.followed_by < 2_000
      UserFollowersCollectWorker.perform_async user.id, ignore_batch: true, ignore_exists: true, ignore_uniqueness: true
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
      UserFollowersCollectWorker.perform_async(user.id, start_cursor: start_cursor, finish_cursor: finish_cursor, ignore_exists: true, ignore_batch: true)
    end
  end

  def self.jobs_exists? user_id
    exists = false
    queue_jobs = Sidekiq::Queue.new(UserFollowersCollectWorker.sidekiq_options['queue'])
    queue_jobs.each do |job|
      if job.klass == UserFollowersCollectWorker.name && job.args[0].to_i == user_id.to_i
        exists = true
        break
      end
    end

    unless exists
      workers = Sidekiq::Workers.new
      workers.each do |process_id, thread_id, work|
        if work['payload']['class'] == UserFollowersCollectWorker.name && work['payload']['args'][0].to_i == user_id.to_i
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