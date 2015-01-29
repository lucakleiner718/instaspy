class GeneralMailer < ActionMailer::Base

  def users_emails list
    csv_string = CSV.generate do |csv|
      csv << ['Name', 'Username', 'Email', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
      list.each do |row|
        user = row[:user]
        begin
          csv << [user.full_name, user.username, row[:email], user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
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

end
