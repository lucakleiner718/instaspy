class FollowersReportMailer < ActionMailer::Base

  def user origin
    followers = origin.followers

    csv_string = CSV.generate do |csv|
      csv << ['Insta ID', 'Username', 'Name', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
      followers.find_each do |user|
        csv << [user.insta_id, user.username, user.full_name, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
      end
    end

    if followers.size < 10_000
      attachments["#{origin.username}-followers.csv"] = csv_string
    else

      end

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy followers report #{origin.username}"
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy followers report #{origin.username}"
    end

  end

  def full origin
    followers_ids = origin.user_followers.pluck(:follower_id)

    csv_string = CSV.generate do |csv|
      csv << ['Insta ID', 'Username', 'Name', 'Bio', 'Website', 'Follows', 'Followers', 'Media amount', 'Email']
      followers_ids.in_groups_of(10_000, false) do |group|
        User.where(id: group).each do |user|
          user.update_info! if user.outdated?
          csv << [user.insta_id, user.username, user.full_name, user.bio, user.website, user.follows, user.followed_by, user.media_amount, user.email]
        end
      end
    end

    if followers.size < 10_000
      attachments["#{origin.username}-followers.csv"] = csv_string
    else
      Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
      file_path = "reports/#{origin.username}-followers-#{Time.now.to_i}.csv"
      @file_url = "#{root_url}#{file_path}"
      File.open("public/#{file_path}", 'w') do |f|
        f.puts csv_string
      end
    end

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy followers full report #{origin.username}", from: 'dev@antonzaytsev.com'
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy followers full report #{origin.username}"
    end
  end

  def weekly origins
    @start = 7.days.ago.utc.beginning_of_day
    @finish = 1.day.ago.utc.end_of_day
    @files = []

    origins = [origins] unless origins.is_a?(Array)

    origins.each do |origin|
      followers = Follower.where(user_id: origin.id)
      followers = followers.includes(:follower).where('followers.created_at >= :start AND followers.created_at <= :finish', start: @start, finish: @finish)

      csv_string = CSV.generate do |csv|
        csv << ['Insta ID', 'Username', 'Name', 'Bio', 'Website', 'Follows', 'Followers', 'Media amount', 'Email']
        followers.find_each do |follower|
          user = follower.follower
          begin
            user.update_info!
            csv << [user.insta_id, user.username, user.full_name, user.bio, user.website, user.follows, user.followed_by, user.media_amount, user.email]
          rescue => e
            # somehow we don't have user record, just delete link-follower
            puts "Catched error #{e.message.red}"
            if user.blank?
              follower.destroy
            end
          end
        end
      end

      if followers.size < 10
        attachments["#{origin.username}-followers.csv"] = csv_string
      else
        Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
        file_path = "reports/#{origin.username}-followers-#{Time.now.to_i}.csv"
        @files << [origin, "#{root_url}#{file_path}"]
        File.open("public/#{file_path}", 'w') do |f|
          f.puts csv_string
        end
      end
    end

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy followers weekly #{@start.strftime('%m/%d/%y')} - #{@finish.strftime('%m/%d/%y')} report #{origins.size < 6 ? origins.map{|o| o.username}.join(',') : ''}", from: 'dev@antonzaytsev.com'
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy followers weekly #{@start.strftime('%m/%d/%y')} - #{@finish.strftime('%m/%d/%y')} report #{origins.size < 6 ? origins.map{|o| o.username}.join(',') : ''}"
    end
  end

  # Get all followers for provided tags and save them in file
  # Params:
  # tags (array) - array of tag names
  def self.tags_publishers tags
    files = []
    tags.each do |tag_name|
      ids = Tag.get(tag_name).publishers.pluck(:id)

      csv_string = CSV.generate do |csv|
        csv << ['Username', 'Name', 'Bio', 'Website', 'Follows', 'Followers', 'Media amount', 'Email']
        ids.in_groups_of(10_000, false) do |group|
          User.where(id: group).each do |user|
            csv << [user.username, user.full_name, user.bio, user.website, user.follows, user.followed_by, user.media_amount, user.email]
          end
        end
      end

      path = "reports/#{tag_name}-publishers-#{Time.now.to_i}.csv"
      File.write "public/#{path}", csv_string
      files << "http://107.170.110.156/reports/#{path}"
    end

    files
  end

end
