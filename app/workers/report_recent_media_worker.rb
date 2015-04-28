class ReportRecentMediaWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args[0], args[1] ] }

  def perform user_id, report_id
    user = User.where(id: user_id).first
    report = Report.find(report_id)

    if user
      user.recent_media total_limit: 20
    end

    report.data['processed_ids'] << user_id
    report.save
  end
end