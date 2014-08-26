class ReportMailer < ActionMailer::Base
  def weekly csv_files, starts, ends
    csv_files.each do |tag_name, csv_string|
      attachments["#{tag_name}.csv"] = csv_string
    end
#"rob@ladylux.com", bcc:
    mail to: 'me@antonzaytsev.com', subject: "Weekly InstaSpy report #{starts.strftime('%m/%d/%y')}-#{ends.strftime('%m/%d/%y')}"
  end
end
