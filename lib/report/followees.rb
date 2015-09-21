class Report::Followees < Report::Base

  def reports_in_process
    @parts_amount = 3
    ['likes', 'location', 'feedly'].each do |info|
      @parts_amount += 1 if @report.output_data.include?(info)
    end

    self.process_user_info

    if @report.steps.include? 'user_info'
      @report.amounts[:followees] = User.where(id: @report.processed_ids).pluck(:follows).sum
    end

    if @report.data['only_download']
      if @report.steps.include?('user_info') && !@report.steps.include?('followees')
        @report.steps.push 'followees'
        @report.save
      end
    else
      self.grab_followees
    end

    self.update_followees

    # after followeуs list grabbed and all followees updated
    if @report.steps.include?('followees_info')
      self.process_likes @followees_ids
      self.process_location @followees_ids
      self.process_feedly @followees_ids
    end

    @progress += @report.steps.size.to_f / @parts_amount
    @report.progress = @progress.round(2) * 100

    @report.save!

    if @parts_amount == @report.steps.size
      self.finish
    end

    @report.save
  end

  def finish
    files = []

    header = ['ID', 'Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followers', 'Email']
    header += ['Country', 'State', 'City'] if @report.output_data.include? 'location'
    header += ['AVG Likes'] if @report.output_data.include? 'likes'
    header += ['Feedly Subscribers'] if @report.output_data.include? 'feedly'
    header.slice! 4,1 if @report.output_data.include?('slim') || @report.output_data.include?('slim_followers')
    header += ['Relation']

    total_followees_amount = 0

    User.where(id: @report.processed_ids).each do |user|
      filename = "#{user.username}-followees-#{Time.now.to_i}.csv"
      unless File.exists? Rails.root.join('tmp', filename)
        csv_string = CSV.generate do |csv|
          csv << header
          followees_ids = Follower.where(follower_id: user.id)
          followees_ids = followees_ids.where("followed_at >= ?", @report.date_from) if @report.date_from
          followees_ids = followees_ids.where("followed_at <= ?", @report.date_to) if @report.date_to
          followees_ids = followees_ids.pluck(:user_id).uniq
          followees = User.where(id: followees_ids)
          followees = followees.where("email is not null").where("followed_by >= ?", 1_000) if @report.output_data.include? 'slim'
          followees = followees.where("followed_by >= ?", 1_000) if @report.output_data.include? 'slim_followers'
          followees.each do |u|
            row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
            row.slice! 4,1 if @report.output_data.include? 'slim' || @report.output_data.include?('slim_followers')
            row.concat [u.location_country, u.location_state, u.location_city] if @report.output_data.include? 'location'
            row.concat [u.avg_likes] if @report.output_data.include? 'likes'
            if @report.output_data.include? 'feedly'
              feedly = u.feedly.first
              row.concat [feedly ? feedly.subscribers_amount : '']
            end
            row << user.username

            csv << row

            total_followees_amount += 1
          end
        end

        File.write Rails.root.join('tmp', filename), csv_string
      end

      files << filename
    end

    if files.size > 0
      zipfilename = Rails.root.join("tmp", "followees-report-#{Time.now.to_i}.zip")
      Zip::File.open(zipfilename, Zip::File::CREATE) do |zipfile|
        files.each do |filename|
          zipfile.add(filename, Rails.root.join('tmp', filename))
        end
      end

      filepath = "reports/users-followees-#{files.size}-#{Time.now.to_i}.zip"
      FileManager.save_file filepath, file: zipfilename
      @report.result_data = filepath

      File.delete(zipfilename) rescue nil
      files.each do |filename|
        File.delete(Rails.root.join('tmp', filename)) rescue nil
      end
    end

    @report.finished_at = Time.now
    @report.status = :finished
    @report.save

    ReportMailer.followees(@report.id).deliver if @report.notify_email.present?

    self.after_finish
  end

  def after_finish
    super
    ReportStopJobs.perform_async @report.id
  end

end
