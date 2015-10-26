class DeleteDuplicatesQueueWorker

  include Sidekiq::Worker
  sidekiq_options unique: true

  def perform
    Sidekiq::Queue.all.each do |queue|
      exists = {}
      deleted_amount = 0
      puts "Queue #{queue.name} has #{queue.size} jobs"
      queue.each(page_size: 500) do |job|
        job_class = job.item['class']
        job_args = job.item['args']
        exists[job.item['class']] ||= []
        if job_args.in?(exists[job_class])
          job.delete
          deleted_amount += 1
          Rails.logger.debug "Job deleted #{job_class} #{job_args} / exists: #{exists[job.item['class']].size} / deleted: #{deleted_amount}"
        else
          exists[job.item['class']] << job.item['args']
        end
      end
    end
  end

end