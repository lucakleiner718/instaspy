class FollowersReportMailer < ActionMailer::Base
  def user origin
    followers = origin.followers

    csv_string = CSV.generate do |csv|
      csv << ['Name', 'Username', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
      followers.find_each do |user|
        csv << [user.full_name, user.username, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
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
end
