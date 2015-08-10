class ReportsController < ApplicationController

  helper_method :sort_column, :sort_direction

  def index
    @reports = Report.order(created_at: :desc, started_at: :desc, finished_at: :desc)

    case params[:format]
      when 'all'

      when 'new', 'in_process', 'finished'
        @reports = @reports.where(status: params[:format])
      else
        @reports = @reports.where(status: ['new', 'in_process'])
    end

    if params[:sort]
      @reports = @reports.order("#{params[:sort]} #{params[:direction]}")
    end

    @reports = @reports.page(params[:page]).per(20)
  end

  def new
    @report = Report.new
  end

  def create
    @report = Report.new report_params
    @report.output_data.select!{|r| r.present?}
    @report.status = 'new'
    @report.date_from = DateTime.strptime(report_params['date_from'], '%m/%d/%Y') if report_params['date_from'].present?
    @report.date_to = DateTime.strptime(report_params['date_to'], '%m/%d/%Y').end_of_day if report_params['date_to'].present?

    if @report.save
      session['report_notify_email'] = @report.notify_email

      csv_string = Report.process_input report_params[:input]

      filepath = "reports/reports_data/report-#{@report.id}-original-input.csv"
      FileManager.save_file filepath, content: csv_string
      @report.update_attribute :original_input, filepath

      ReportProcessNewWorker.perform_async @report.id
      redirect_to reports_path
    else
      render :new
    end
  end

  def followers
  end

  def followers_report
    user = User.get_by_username params[:name]
    if user
      user.update_followers true
      FollowersReportMailer.user(user).deliver
    end
    redirect_to :back
  end

  def update_status
    @report = Report.find(params[:id])
    if params[:status] == 'continue' && @report.status == 'stopped'
      @report.status = @report.started_at.nil? ? 'new' : 'in_process'
    elsif params[:status] == 'stop' && @report.status.in?(['new', 'in_process'])
      @report.status = 'stopped'
    end

    ReportProcessNewWorker.spawn
    ReportProcessProgressWorker.spawn

    @report.save
    respond_to do |format|
      format.json { render json: { success: true, status: @report.status } }
    end
  end

  private

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end

  def sort_column
    Tag.column_names.include?(params[:sort]) ? params[:sort] : "name"
  end

  def report_params
    params.require(:report).permit(:input, :format, :notify_email, :note, :date_from, :date_to, output_data: [])
  end
end
