class ReportStopJobs

  include Sidekiq::Worker
  sidekiq_options unique: true, queue: :critical

  def perform report_id, report=nil
    @report = report || Report.find(report_id)

    if @report.format == 'followers'
      stop_followers_grab
    elsif @report.format == 'followees'
      stop_followees_grab
    end
  end

  private

  def stop_followers_grab
    # Stop followers update jobs
    queue_jobs = Sidekiq::Queue.new(UserFollowersWorker.sidekiq_options['queue'])
    queue_jobs.each do |job|
      if job.klass == 'UserFollowersWorker' && job.args[0].to_s.in?(@report.processed_ids)
        job.delete
      end
    end
  end

  def stop_followees_grab
    # Stop followers update jobs
    queue_jobs = Sidekiq::Queue.new(UserFolloweesWorker.sidekiq_options['queue'])
    queue_jobs.each do |job|
      if job.klass == 'UserFolloweesWorker' && job.args[0].to_s.in?(@report.processed_ids)
        job.delete
      end
    end
  end

end