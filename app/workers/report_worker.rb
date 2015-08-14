class ReportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical

  def perform *args
    options = args.extract_options!

    date_to = options[:date_to] || 1.day.ago.end_of_day
    date_from = options[:date_from] || 6.days.ago(date_to).beginning_of_day

    r = Report.new input: Tag.exportable.pluck(:name).join("\r\n"), format: 'tags',
      date_from: date_from, date_to: date_to,
      notify_email: (ENV['insta_debug'] || Rails.env.development? ? 'me@antonzaytsev.com' : 'rob@ladylux.com')

    r.data['email_subject'] = "Weekly InstaSpy report #{date_to.strftime('%m/%d/%y')}-#{date_from.strftime('%m/%d/%y')}"
    r.note = "Weekly tags publishers report #{date_to.strftime('%m/%d/%y')}-#{date_from.strftime('%m/%d/%y')}"

    r.save

    # Reporter.media_report
  end
end