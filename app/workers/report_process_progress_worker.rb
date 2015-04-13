class ReportProcessProgressWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform report_id
    report = Report.where(status: :in_process).where(id: report_id).first

    return false unless report

    if report.format == 'followers'
      jobs = report.jobs.split(',')
      jobs.map! do |job_id|
        Sidekiq::Status::get_all job_id
      end

      job_progress = jobs.map{|r| r['status'] == 'complete'}.size / jobs.size.to_f * 100

      if job_progress == 100
        followers_ids = Follower.where(user_id: report.input_csv.select{|r| r[2].present?}.map{|r| r[2]}).pluck(:follower_id)
        followers_size = User.where(id: followers_ids).size
        not_updated_followers = User.where(id: followers_ids).where('grabbed_at is null OR grabbed_at < ?', 3.weeks.ago).where(private: false).pluck(:id)

        if not_updated_followers.size == 0
          report.status = :finished
          report.finished_at = Time.now
          report.progress = 100
        else
          report.progress = 100 - (not_updated_followers.size/followers_size.to_f*10).to_i
          report.progress = 99 if report.progress == 100
          not_updated_followers.each { |uid| UserWorker.perform_async uid, true }
        end
      else
        followers_ids = Follower.where(user_id: report.input_csv.select{|r| r[2].present?}.map{|r| r[2]}).pluck(:follower_id)
        not_updated_followers = User.where(id: followers_ids).where('grabbed_at is null OR grabbed_at < ?', 3.weeks.ago).where(private: false).pluck(:id)
        not_updated_followers.each { |uid| UserWorker.perform_async uid }
      end

      if report.status == :finished
        files = []

        report.input_csv.select{|r| r[2].present?}.each do |row|
          user = User.find(row[2])
          next unless user
          csv_string = CSV.generate do |csv|
            csv << ['ID', 'Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followers', 'Email']
            user.followers.each do |u|
              csv << [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
            end
          end

          files << ["#{user.username}-followers-#{Time.now.to_i}.csv", csv_string]
        end

        if files.size > 0
          stringio = Zip::OutputStream.write_buffer do |zio|
            files.each do |file|
              zio.put_next_entry(file[0])
              zio.write file[1]
            end
          end
          stringio.rewind
          binary_data = stringio.sysread

          filepath = "reports/users-followers-#{files.size}-#{Time.now.to_i}.zip"
          File.write("public/#{filepath}", binary_data)
          report.result_data = filepath
          report.save
        end

        ReportMailer.finished(report.id).deliver
      end
      report.save
    end
  end

  def self.spawn
    Report.where(status: :in_process).each do |report|
      self.perform_async report.id
    end
  end
end