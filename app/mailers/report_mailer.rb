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

  def followers report_id
    @report = Report.find(report_id)
    @file = FileManager.file_url @report.result_data
    mail to: @report.notify_email, subject: "Requested InstaSpy followers report"
  end

  def followees report_id
    @report = Report.find(report_id)
    @file = FileManager.file_url @report.result_data
    mail to: @report.notify_email, subject: "Requested InstaSpy followees report"
  end

  def users report_id
    @report = Report.find(report_id)
    @file = FileManager.file_url @report.result_data
    mail to: @report.notify_email, subject: "Requested InstaSpy users report"
  end

  def users_export report_id
    @report = Report.find(report_id)
    @file = FileManager.file_url @report.result_data
    mail to: @report.notify_email, subject: "Requested InstaSpy users export"
  end

  def tags report_id
    @report = Report.find(report_id)
    @file = FileManager.file_url @report.result_data
    mail to: @report.notify_email, subject: (@report.data['email_subject'] || "Requested InstaSpy tags publishers report")
  end
end
