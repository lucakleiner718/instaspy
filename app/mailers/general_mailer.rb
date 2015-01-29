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
    file_path = "reports/tag-authors-#{Time.now.to_i}.csv"
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
          csv << [em, user.full_name, user.username, user.bio, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
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

end
