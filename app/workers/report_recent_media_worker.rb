class ReportRecentMediaWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args[0], args[1] ] }

  def perform user_id, report_id
    user = User.where(id: user_id).first

    if user
      user.recent_media total_limit: 20
    end

    Report.find(report_id).push(tmp_list1: user_id)
  end
end