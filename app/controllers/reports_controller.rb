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
    end

    @reports = @reports.page(params[:page]).per(20)
  end

  def new
    @report = Report.new
  end

  def create
    @report = Report.new report_params
    @report.progress = 0
    @report.format = 'followers'

    if @report.save
      usernames = report_params[:input].split("\r\n").map{|el| el.split("\r")}.flatten.map{|el| el.split("\n")}.flatten
      csv_string = CSV.generate do |csv|
        usernames.each do |username|
          csv << [username]
        end
      end

      Dir.mkdir(Rails.root.join("public/reports/reports_data")) unless Dir.exist?(Rails.root.join("public/reports/reports_data"))
      File.write(Rails.root.join("public/reports/reports_data/report-#{@report.id}.csv"), csv_string)

      @report.update_attribute :input_data, "reports/reports_data/report-#{@report.id}.csv"
      ReportProcessNewWorker.perform_async @report.id
      redirect_to reports_path
    else
      render :new
    end
  end

  def followers
  end

  def followers_report
    user = User.add_by_username params[:name]
    if user
      user.update_followers true
      FollowersReportMailer.user(user).deliver
    end
    redirect_to :back
  end

  private

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end

  def sort_column
    Tag.column_names.include?(params[:sort]) ? params[:sort] : "name"
  end

  def report_params
    params.require(:report).permit(:input, :format, :notify_email)
  end
end
