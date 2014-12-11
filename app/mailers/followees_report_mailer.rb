class FolloweesReportMailer < ActionMailer::Base

  def user origin
    followees = origin.followees

    csv_string = CSV.generate do |csv|
      csv << ['Name', 'Username', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
      followees.find_each do |user|
        csv << [user.full_name, user.username, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
      end
    end

    if followees.size < 10_000
      attachments["#{origin.username}-followers.csv"] = csv_string
    else

      end

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy followees report #{origin.username}"
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy followees report #{origin.username}"
    end

  end

  def full origins
    if origins.class.name == 'User'
      origins = [origins]
    end

    @file_urls = []

    origins.each do |origin|
      followees = origin.followees

      csv_string = CSV.generate do |csv|
        csv << ['Name', 'Username', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
        followees.find_each do |user|
          csv << [user.full_name, user.username, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
        end
      end

      if followees.size < 10_000
        attachments["#{origin.username}-followees.csv"] = csv_string
      else
        Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
        file_path = "reports/#{origin.username}-followees-#{Time.now.to_i}.csv"
        @file_urls << "#{root_url}#{file_path}"
        File.open("public/#{file_path}", 'w') do |f|
          f.puts csv_string
        end
      end
    end

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy followees full report #{origins.size > 5 ? "for #{origins.size} accounts" : origins.map{|el|el.username}.join(', ')}", from: 'dev@antonzaytsev.com'
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy followees full report #{origins.size > 5 ? "for #{origins.size} accounts" : origins.map{|el|el.username}.join(', ')}"
    end
  end

  def weekly origin
    followees = Follower.where(follower_id: origin.id)

    @start = 7.days.ago.utc.beginning_of_day
    @finish = 1.day.ago.utc.end_of_day

    followees = followees.includes(:followee).where('followers.created_at >= :start AND followers.created_at <= :finish', start: @start, finish: @finish)

    csv_string = CSV.generate do |csv|
      csv << ['Name', 'Username', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
      followees.find_each do |followee|
        user = followee.followee
        begin
          csv << [user.full_name, user.username, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
        rescue Exception => e
          # somehow we don't have user record, just delete link-follower
          if user.blank?
            followee.destroy
          end
        end
      end
    end

    if followees.size < 10
      attachments["#{origin.username}-followees.csv"] = csv_string
    else
      Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
      file_path = "reports/#{origin.username}-followees-#{Time.now.to_i}.csv"
      @file_url = "#{root_url}#{file_path}"
      File.open("public/#{file_path}", 'w') do |f|
        f.puts csv_string
      end
    end

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy followees weekly #{@start.strftime('%m/%d/%y')} - #{@finish.strftime('%m/%d/%y')} report #{origin.username}", from: 'dev@antonzaytsev.com'
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy followees weekly #{@start.strftime('%m/%d/%y')} - #{@finish.strftime('%m/%d/%y')} report #{origin.username}"
    end
  end

end
