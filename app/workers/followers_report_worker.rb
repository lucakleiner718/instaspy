class FollowersReportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical, retry: true, backtrace: true

  def perform *args
    options = args.extract_options!

    input = User.where(id: TrackUser.where(followers: true).pluck(:user_id)).pluck(:insta_id)

    return if input.size == 0

    date_to = options[:date_to] || 1.day.ago.end_of_day
    date_from = options[:date_from] || 6.days.ago(date_to).beginning_of_day

    r = Report.new input: input.join("\r\n"), format: 'followers',
      date_from: date_from, date_to: date_to,
      notify_email: (ENV['insta_debug'] || Rails.env.development? ? 'me@antonzaytsev.com' : 'rob@ladylux.com')

    r.data['email_subject'] = "InstaSpy followers weekly #{date_to.strftime('%m/%d/%y')} - #{date_from.strftime('%m/%d/%y')} report"
    r.data['only_download'] = true
    r.note = "Weekly followers report #{date_to.strftime('%m/%d/%y')}-#{date_from.strftime('%m/%d/%y')} for #{input.size} selected accounts"

    r.save
  end
end