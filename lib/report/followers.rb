class Report::Followers < Report::Base

  def reports_in_process
    @parts_amount = 3
    ['likes', 'location', 'feedly'].each do |info|
      @parts_amount += 1 if @report.output_data.include?(info)
    end

    self.process_user_info

    self.grab_followers
    self.update_followers

    # after followers list grabbed and all followers updated
    if @report.steps.include?('followers_info')
      self.process_likes @followers_ids
      self.process_location @followers_ids
      self.process_feedly @followers_ids
    end

    @progress += @report.steps.size.to_f / @parts_amount
    @report.progress = @progress.round(2) * 100

    @report.save!

    if @parts_amount == @report.steps.size
      self.finish
    end

    @report.save!
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
      filename = "#{user.username}-followers-#{Time.now.to_i}.csv"
      unless File.exists? Rails.root.join('tmp', filename)
        csv_string = CSV.generate do |csv|
          csv << header
          followers_ids = Follower.where(user_id: user.id).pluck(:follower_id).uniq
          followers = User.where(id: followers_ids)
          followers = followers.where("email is not null").where("followed_by >= ?", 1_000) if @report.output_data.include? 'slim'
          followers = followers.where("followed_by >= ?", 1_000) if @report.output_data.include? 'slim_followers'
          followers.each do |u|
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

        File.write Rails.root.join('tmp', filename), csv_string
      end
      files << filename
    end

    if files.size > 0
      zipfilename = Rails.root.join("tmp", "followers-report-#{Time.now.to_i}.zip")
      Zip::File.open(zipfilename, Zip::File::CREATE) do |zipfile|
        files.each do |filename|
          zipfile.add(filename, Rails.root.join('tmp', filename))
        end
      end

      filepath = "reports/users-followers-#{files.size}-#{Time.now.to_i}.zip"
      FileManager.save_file filepath, file: zipfilename
      @report.result_data = filepath

      File.delete(zipfilename)
      files.each { |filename| File.delete(Rails.root.join('tmp', filename)) }
    end

    @report.finished_at = Time.now
    @report.status = :finished
    @report.save

    ReportMailer.followers(@report.id).deliver if @report.notify_email.present?

    self.after_finish
  end
end
