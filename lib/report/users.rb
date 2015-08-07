class Report::Users < Report::Base

  def reports_in_process
    @parts_amount = 1
    ['likes', 'comments', 'location', 'feedly'].each do |info|
      @parts_amount += 1 if @report.output_data.include?(info)
    end
    @parts_amount += 2 if @report.output_data.include?('followers_analytics')
    @followers_analytics_groups = ['0-100', '100-250', '250-500', '500-1000', '1,000-10,000', '10,000+']

    self.process_user_info

    if @report.steps.include?('user_info')
      if @report.output_data.include?('followers_analytics')
        self.grab_followers
        self.update_followers
      end
      self.process_likes
      self.process_comments
      self.process_location
      self.process_feedly
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
    header += ['AVG Comments'] if @report.output_data.include? 'comments'
    header += ['Feedly Subscribers'] if @report.output_data.include? 'feedly'
    header += ['Last media date'] if @report.output_data.include? 'last_media_date'
    if @report.output_data.include? 'followers_analytics'
      header += @followers_analytics_groups
    end

    if @report.output_data.include? 'last_media_date'
      media_list = {}
      @report.processed_ids.in_groups_of(1_000, false) do |uids|
        media_list = media_list.merge Media.where(user_id: uids).group_by {|m| m.user_id }.inject({}){|o, (k,v)| o[k.to_s] = v.sort{|m1, m2| m1.created_time <=> m2.created_time }.last; o}
      end
    end

    csv_string = CSV.generate do |csv|
      csv << header
      User.where(id: @report.processed_ids).each do |u|
        row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
        row.concat [u.location_country, u.location_state, u.location_city] if @report.output_data.include? 'location'
        row.concat [u.avg_likes] if @report.output_data.include? 'likes'
        row.concat [u.avg_comments] if @report.output_data.include? 'comments'
        if @report.output_data.include? 'feedly'
          feedly = u.feedly.first
          row.concat [feedly ? feedly.subscribers_amount : '']
        end
        if @report.output_data.include? 'last_media_date'
          row << media_list[u.id.to_s].created_time.strftime('%m/%d/%Y %H:%M:%S') if media_list[u.id.to_s]
        end

        if @report.output_data.include? 'followers_analytics'
          amounts = {}
          followers_ids = Follower.where(user_id: u.id).pluck(:follower_id)
          followers_ids.in_groups_of(10_000, false) do |ids|
            User.where(id: ids).pluck(:followed_by).each do |followers_size|
              @followers_analytics_groups.each do |group|
                amounts[group] ||= 0
                from, to = group.gsub(/,|\+/, '').split('-').map(&:to_i)
                if to.present?
                  if followers_size >= from && followers_size < to
                    amounts[group] += 1
                  end
                else
                  if followers_size >= from
                    amounts[group] += 1
                  end
                end
              end
            end
          end

          row += @followers_analytics_groups.map{|group| amounts[group] }
        end

        csv << row
      end
    end

    basename = "users-#{@report.processed_ids.size}-report-#{Time.now.to_i}"

    files << ["#{basename}.csv", csv_string]

    if files.size > 0
      stringio = Zip::OutputStream.write_buffer do |zio|
        files.each do |file|
          zio.put_next_entry(file[0])
          zio.write file[1]
        end
      end
      stringio.rewind
      binary_data = stringio.sysread

      filepath = "reports/#{basename}.zip"
      FileManager.save_file filepath, content: binary_data
      @report.result_data = filepath
    end

    @report.finished_at = Time.now
    @report.save

    ReportMailer.users(@report.id).deliver if @report.notify_email.present?

    self.after_finish
  end
end