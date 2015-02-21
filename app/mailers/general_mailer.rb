class GeneralMailer < ActionMailer::Base

  def users_emails list
    csv_string = CSV.generate do |csv|
      csv << ['Name', 'Username', 'Email', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
      list.each do |user|
        begin
          csv << [user.full_name, user.username, user.email, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
        rescue Exception => e
        end
      end
    end

    Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
    file_path = "reports/users-emails-#{Time.now.to_i}.csv"
    @file = "#{root_url}#{file_path}"
    File.open("public/#{file_path}", 'w') do |f|
      f.puts csv_string
    end

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy users emails report", from: 'dev@antonzaytsev.com'
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy users emails report"
    end
  end

  def tag_authors tag, users
    @tag = tag

    csv_string = CSV.generate do |csv|
      csv << ['Name', 'Username', 'Bio', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
      users.each do |user|
        begin
          csv << [user.full_name, user.username, user.bio, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
        rescue Exception => e
        end
      end
    end

    Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
    file_path = "reports/tag-#{tag.name}-authors-#{Time.now.to_i}.csv"
    @file = "#{root_url}#{file_path}"
    File.open("public/#{file_path}", 'w') do |f|
      f.puts csv_string
    end

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy #{@tag.name} tag authors report", from: 'dev@antonzaytsev.com'
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy #{@tag.name} tag authors report"
    end
  end


  def report_by_emails emails, results
    @emails = emails

    csv_string = CSV.generate do |csv|
      csv << ['Email', 'Full Name', 'Username', 'Bio', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
      emails.each do |em|
        user = results[em]
        if user
          csv << [em].concat(user)
        else
          csv << [em]
        end
      end
    end

    Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
    file_path = "reports/report-by-emails-#{Time.now.to_i}.csv"
    @file = "#{root_url}#{file_path}"
    File.open("public/#{file_path}", 'w') do |f|
      f.puts csv_string
    end

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy report by emails", from: 'dev@antonzaytsev.com'
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy report by emails"
    end
  end

  def get_bio_by_usernames results
    csv_string = CSV.generate do |csv|
      csv << ['Username', 'Bio']
      results.each do |username, bio|
        csv << [username, bio]
      end
    end

    Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
    file_path = "reports/bio-report-by-usernames-#{Time.now.to_i}.csv"
    @file = "#{root_url}#{file_path}"
    File.open("public/#{file_path}", 'w') do |f|
      f.puts csv_string
    end

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy bio report by usernames", from: 'dev@antonzaytsev.com'
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy bio report by usernames"
    end
  end

  def avg_likes_comments csv_string, usernames, not_processed
    @not_processed = not_processed
    Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
    file_path = "reports/avg-likes-comments-#{Time.now.to_i}.csv"
    @file = "#{root_url}#{file_path}"
    File.open("public/#{file_path}", 'w') do |f|
      f.puts csv_string
    end

    sbj = "InstaSpy avg likes and comments report for #{usernames.size} usernames"
    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', from: 'dev@antonzaytsev.com', subject: sbj
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: sbj
    end
  end

  def location_report data, not_processed=[]
    @not_processed = not_processed
    csv_string = CSV.generate do |csv|
      csv << ['Full Name', 'Username', 'Bio', 'Private', 'Country', 'Country and State', 'Location', 'Email']
      data.each do |row|
        user = User.get(row[0])
        location = row[1]
        csv << [user.full_name, user.username, user.bio, (user.private? ? 'Private' : 'Public'), location[:country], location[:state], location[:city], user.email]
      end
    end

    Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
    file_path = "reports/user-location-report-#{Time.now.to_i}.csv"
    @file = "#{root_url}#{file_path}"
    File.open("public/#{file_path}", 'w') do |f|
      f.puts csv_string
    end

    sbj = "InstaSpy users location report for #{data.size} users"
    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', from: 'dev@antonzaytsev.com', subject: sbj, template_name: 'default'
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: sbj, template_name: 'default'
    end
  end

  def by_location csv_string
    Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
    file_path = "reports/media-by-location-report-#{Time.now.to_i}.csv"
    @file = "#{root_url}#{file_path}"
    File.open("public/#{file_path}", 'w') do |f|
      f.puts csv_string
    end

    sbj = "InstaSpy media by location report #{Time.now.strftime('%m/%d/%Y')}"
    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', from: 'dev@antonzaytsev.com', subject: sbj, template_name: 'default'
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: sbj
    end
  end

  def user_locations tag_name, users
    csv_string = CSV.generate do |csv|
      csv << ['Username', 'Full Name', 'Bio', 'Website', 'Follows', 'Followers', 'Media amount', 'AVG Likes', 'AVG Comments', 'State', 'City', 'Email']
      users.each do |user|
        csv << [user.username, user.full_name, user.bio, user.website, user.follows, user.followed_by, user.media_amount, user.avg_likes, user.avg_comments, location[:state], location[:city], user.email]
      end
    end

    Dir.mkdir('public/reports') unless Dir.exists?('public/reports')
    file_path = "reports/users-location-report-#{tag_name}-#{Time.now.to_i}.csv"
    @file = "#{root_url}#{file_path}"
    File.open("public/#{file_path}", 'w') do |f|
      f.puts csv_string
    end

    sbj = "InstaSpy users location report by tag #{tag_name} #{Time.now.strftime('%m/%d/%Y')}"
    # if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', from: 'dev@antonzaytsev.com', subject: sbj, template_name: 'default'
    # else
    #   mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: sbj
    # end
  end

end
