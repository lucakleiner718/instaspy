class UserFolloweesCollectWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] },
    queue: :fols_collect, default_expiration: 3 * 60 * 60

  def perform user_id, *args
    options = args.extract_options!
    options.symbolize_keys!

    begin
      user = User.find(user_id)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.debug e.message
      return false
    end

    user.update_info! unless user.follows

    present_ratio = user.followees_size / user.follows.to_f

    return false if user.private? || (user.followees_size >= user.follows && present_ratio < 1.2)

    UserFolloweesCollect.perform user: user, options: options
  end

  # def self.delete_exists_jobs user_id
  #   queue_jobs = Sidekiq::Queue.new(UserFolloweesCollectWorker.sidekiq_options['queue'])
  #   queue_jobs.each do |job|
  #     if job.klass == UserFolloweesCollectWorker.name && job.args[0].to_i == user_id.to_i
  #       job.delete
  #     end
  #   end
  # end
  #
  # def self.get_jobs user_id
  #   jobs = []
  #   queue_jobs = Sidekiq::Queue.new(UserFolloweesCollectWorker.sidekiq_options['queue'])
  #   queue_jobs.each do |job|
  #     if job.klass == UserFolloweesCollectWorker.name && job.args[0].to_i == user_id.to_i
  #       jobs << job
  #     end
  #   end
  #   jobs
  # end
  #
  # def batch_collect user, *args
  #   options = args.extract_options!
  #   return if UserFolloweesCollectWorker.jobs_exists?(user.id) && !options[:force_batch]
  #
  #   user.update_info! force: true
  #
  #   return if user.followees_size >= user.follows
  #
  #   if user.follows < 2_000
  #     UserFolloweesCollectWorker.perform_async user.id, ignore_batch: true, ignore_exists: true, ignore_uniqueness: true
  #     return true
  #   end
  #
  #   beginning = DateTime.parse('2010-09-01')
  #   start = Time.now.to_i
  #   seconds_since_start = start - beginning.to_i
  #   worker_days = 10.days
  #   amount = (seconds_since_start/worker_days.to_f).ceil
  #
  #   amount.times do |i|
  #     offset = i*worker_days
  #     start_cursor = i > 0 ? start - offset : nil
  #     break if start_cursor && start_cursor < 0
  #     finish_cursor = i+1 < amount ? start-(i+1)*worker_days : nil
  #     UserFolloweesCollectWorker.perform_async(user.id, start_cursor: start_cursor, finish_cursor: finish_cursor, ignore_exists: true, ignore_batch: true)
  #   end
  # end
  #
  # def self.jobs_exists? user_id
  #   exists = false
  #   queue_jobs = Sidekiq::Queue.new(UserFolloweesCollectWorker.sidekiq_options['queue'])
  #   queue_jobs.each do |job|
  #     if job.klass == UserFolloweesCollectWorker.name && job.args[0].to_i == user_id.to_i
  #       exists = true
  #       break
  #     end
  #   end
  #
  #   unless exists
  #     workers = Sidekiq::Workers.new
  #     workers.each do |process_id, thread_id, work|
  #       if work['payload']['class'] == UserFolloweesCollectWorker.name && work['payload']['args'][0].to_i == user_id.to_i
  #         if work['payload']['args'][1] && work['payload']['args'][1]['ignore_batch']
  #           exists = true
  #           break
  #         end
  #       end
  #     end
  #   end
  #
  #   exists
  # end

end