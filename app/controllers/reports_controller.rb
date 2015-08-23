class ReportsController < ApplicationController

  helper_method :sort_column, :sort_direction

  def index
    @reports = Report.all

    case params[:format]
      when 'all'

      when 'new', 'in_process', 'finished'
        @reports = @reports.where(status: params[:format])
      else
        @reports = @reports.where(status: ['new', 'in_process'])
    end

    if params[:sort]
      @reports = @reports.order("#{params[:sort]} #{params[:direction]}")
    elsif params[:format] == 'finished'
      @reports = @reports.order(finished_at: :desc)
    else
      @reports = @reports.order(created_at: :desc, started_at: :desc, finished_at: :desc)
    end

    @reports = @reports.page(params[:page]).per(20)
  end

  def new
    @report = Report.new
  end

  def create
    @report = Report.new report_params

    if @report.format == 'users-export'
      @report.data['country'] = @report.country if @report.country.present?
      @report.data['state'] = @report.state if @report.state.present?
      @report.data['city'] = @report.city if @report.city.present?
    end

    @report.output_data.select!{|r| r.present?}
    @report.date_from = DateTime.strptime(report_params['date_from'], '%m/%d/%Y') if report_params['date_from'].present?
    @report.date_to = DateTime.strptime(report_params['date_to'], '%m/%d/%Y').end_of_day if report_params['date_to'].present?

    if @report.save
      session['report_notify_email'] = @report.notify_email
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

    @report.save

    ReportProcessNewWorker.spawn
    ReportProcessProgressWorker.spawn

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
    params.require(:report).permit(:input, :format, :notify_email, :note, :date_from, :date_to, :country, :state, :city, output_data: [])
  end
end
