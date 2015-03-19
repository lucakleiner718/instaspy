class ReportMailer < ActionMailer::Base
  def weekly binary_file, starts, ends
    attachments["weekly-report-#{Time.now.strftime('%Y%m%d')}.zip"] = binary_file
    ends = ends.class.name == 'String' ? Time.parse(ends) : ends
    starts = starts.class.name == 'String' ? Time.parse(starts) : starts

    if ENV['insta_debug'] || Rails.env.development?
      mail to: 'me@antonzaytsev.com', subject: "Weekly InstaSpy report #{starts.strftime('%m/%d/%y')}-#{ends.strftime('%m/%d/%y')}"
    else
      mail to: "rob@ladylux.com", bcc: 'me@antonzaytsev.com', subject: "Weekly InstaSpy report #{starts.strftime('%m/%d/%y')}-#{ends.strftime('%m/%d/%y')}"
    end
  end
end
