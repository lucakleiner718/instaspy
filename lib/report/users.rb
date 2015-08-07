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
                  if followers_size.between?(from, to)
                    amounts[group] += 1
                  end
                else
                  amounts[group] += 1
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

  # def get_followers ids
  #   if @report.output_data.include?('followers_analytics') && !@report.steps.include?('followers_grabbed')
  #     users = User.where(id: @report.processed_ids).not_private.where("followers_updated_at is null OR followers_updated_at < ?", 3.days.ago).map{|u| [u.id, u.followed_by, u.followers_size, u]}
  #     for_update = users.select{ |r| r[2]/r[1].to_f < 0.95 || r[2]/r[1].to_f > 1.2 }
  #
  #     if for_update.size == 0
  #       @report.steps.push 'followers_grabbed'
  #       @report.save
  #     else
  #       for_update.each do |row|
  #         if row[1] < 2_000 || (row[2]/row[1].to_f > 1.2)
  #           UserFollowersWorker.perform_async row[0], ignore_exists: true
  #         else
  #           row[3].update_followers_batch
  #         end
  #       end
  #       @progress += (users.size - for_update.size) / users.size.to_f / @parts_amount
  #     end
  #   end
  # end
  #
  # def update_followers ids
  #   if @report.data['followers_file'].blank?
  #     # ids of ALL followers of provided users
  #     followers_ids = Follower.where(user_id: ids)
  #     followers_ids = followers_ids.where("followed_at >= ?", @report.date_from) if @report.date_from
  #     followers_ids = followers_ids.where("followed_at <= ?", @report.date_to) if @report.date_to
  #     followers_ids = followers_ids.pluck(:follower_id).uniq
  #
  #     filepath = "reports/reports_data/report-#{@report.id}-followers-ids"
  #     FileManager.save_file filepath, content: followers_ids.join(',')
  #     @report.data['followers_file'] = filepath
  #
  #     @report.amounts[:followers] = followers_ids.size
  #     @report.save
  #   else
  #     followers_ids = FileManager.read_file(@report.data['followers_file']).split(',')
  #   end
  #
  #   @followers_ids = followers_ids
  #
  #   if @report.output_data.include?('followers_analytics') && !@report.steps.include?('followers_updated')
  #     # update followers info, so in report we will have actual media amount, followers and etc. data
  #     followers_to_update = self.get_cached('followers_to_update', followers_ids)
  #
  #     not_updated = []
  #     followers_to_update.in_groups_of(10_000, false) do |ids|
  #       # grab all users without data and data outdated for 7 days
  #       users = User.where(id: ids).outdated(7.days).pluck(:id, :grabbed_at)
  #       # select users only without data and outdated for 8 days, to avoid adding new users on each iteration
  #       list = users.select{|r| r[1].blank? || r[1] < 8.days.ago}.map(&:first)
  #       if list.size > 0
  #         not_updated.concat list
  #         list.each { |uid| UserWorker.perform_async uid }
  #       end
  #     end
  #
  #     if not_updated.size == 0
  #       self.delete_cached('followers_to_update')
  #       @report.steps.push 'followers_updated'
  #     else
  #       self.save_cached('followers_to_update', not_updated)
  #       @progress += (followers_ids.size - not_updated.size) / followers_ids.size.to_f / @parts_amount
  #     end
  #     @report.save
  #   end
  # end
end