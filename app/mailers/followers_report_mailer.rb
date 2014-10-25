class FollowersReportMailer < ActionMailer::Base
  def user origin
    csv_string = CSV.generate do |csv|
      csv << ['Name', 'Username', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
      origin.followers.each do |user|
        csv << [user.full_name, user.username, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
      end
    end
    attachments["#{origin.username}-followers.csv"] = csv_string

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "InstaSpy followers report #{origin.username}"
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "InstaSpy followers report #{origin.username}"
    end

  end
end
