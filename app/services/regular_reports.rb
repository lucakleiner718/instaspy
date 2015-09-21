class RegularReports

  def self.followers_weekly
    input = User.where(id: TrackUser.where(followers: true).pluck(:user_id)).pluck(:insta_id)

    return if input.size == 0

    date_to = 1.day.ago.end_of_day
    date_from = 6.days.ago(date_to).beginning_of_day

    report = Report.new input: input.join("\r\n"), format: 'followers',
                        date_from: date_from, date_to: date_to,
                        notify_email: (ENV['insta_debug'] || Rails.env.development? ? 'me@antonzaytsev.com' : 'rob@ladylux.com')

    report.data['email_subject'] = "InstaSpy followers weekly #{date_to.strftime('%m/%d/%y')} - #{date_from.strftime('%m/%d/%y')} report"
    report.data['only_download'] = true
    report.note = "Weekly followers report #{date_to.strftime('%m/%d/%y')}-#{date_from.strftime('%m/%d/%y')} for #{input.size} selected accounts"

    report.save
  end

  def self.publishers_weekly
    date_to = 1.day.ago.end_of_day
    date_from = 6.days.ago(date_to).beginning_of_day

    report = Report.new input: Tag.exportable.pluck(:name).join("\r\n"), format: 'tags',
                        date_from: date_from, date_to: date_to,
                        notify_email: (ENV['insta_debug'] || Rails.env.development? ? 'me@antonzaytsev.com' : 'rob@ladylux.com')

    report.data['email_subject'] = "Weekly InstaSpy report #{date_to.strftime('%m/%d/%y')}-#{date_from.strftime('%m/%d/%y')}"
    report.note = "Weekly tags publishers report #{date_to.strftime('%m/%d/%y')}-#{date_from.strftime('%m/%d/%y')}"

    report.save
  end

end