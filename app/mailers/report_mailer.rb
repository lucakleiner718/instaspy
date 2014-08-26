class ReportMailer < ActionMailer::Base
  default from: "instaspy@digitallylux.com"

  def weekly csv_files, starts, ends
    csv_files.each do |tag_name, csv_string|
      attachments["#{tag_name}.csv"] = csv_string
    end

    mail to: "me@antonzaytsev.com", subject: "Weekly report #{starts.strftime('%m/%d/%y')}-#{ends.strftime('%m/%d/%y')}"
  end
end
