class Report::Followees < Report::Base

  def reports_in_process
    @parts_amount = 3
    ['likes', 'location', 'feedly'].each do |info|
      @parts_amount += 1 if @report.output_data.include?(info)
    end

    self.process_user_info

    self.grab_followees
    self.update_followees

    # after followeуs list grabbed and all followees updated
    if @report.steps.include?('followees_info')
      self.process_likes @followees_ids
      self.process_location @followees_ids
      self.process_feedly @followees_ids
    end

    @progress += @report.steps.size.to_f / @parts_amount
    @report.progress = @progress.round(2) * 100

    if @parts_amount == @report.steps.size
      @report.status = 'finished'
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

    User.where(id: @report.processed_ids).each do |user|
      csv_string = CSV.generate do |csv|
        csv << header
        followees_ids = Follower.where(follower_id: user.id).pluck(:user_id)
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
        end
      end

      files << ["#{user.username}-followees-#{Time.now.to_i}.csv", csv_string]
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

      filepath = "reports/users-followees-#{files.size}-#{Time.now.to_i}.zip"
      FileManager.save_file filepath, content: binary_data
      @report.result_data = filepath
    end

    @report.finished_at = Time.now
    @report.save

    ReportMailer.followees(@report.id).deliver if @report.notify_email.present?

    self.after_finish
  end
end
