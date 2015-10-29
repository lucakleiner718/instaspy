class ReportRecentMediaWorker
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed, unique_args: -> (args) { [ args[0], args[1] ] }

  def perform user_id, report_id
    user = User.where(id: user_id).first

    if user
      user.recent_media total_limit: 20
    end

    report = Report.find(report_id)
    report.tmp_list1.push user_id
    report.save
  end
end