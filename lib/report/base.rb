class Report::Base

  def initialize report
    @report = report
  end

  def process_users_input
    processed_input = @report.original_csv.map(&:first)

    insta_ids = processed_input.select{|r| r.numeric?}.map(&:to_i)
    usernames = processed_input - insta_ids

    processed_data = []

    if insta_ids.size > 0
      found_insta_ids = User.in(insta_id: insta_ids).pluck(:insta_id, :id)
      (insta_ids - found_insta_ids.map(&:first)).each do |insta_id|
        u = User.create(insta_id: insta_id)
        found_insta_ids << [u.insta_id, u.id] if u && u.valid?
      end
      processed_data.concat found_insta_ids
    end

    if usernames.size > 0
      found_usernames = User.in(username: usernames).pluck(:username, :id)
      (usernames - found_usernames.map(&:first)).each do |username|
        u = User.get(username)
        found_usernames << [u.username, u.id] if u && u.valid?
      end
      processed_data.concat found_usernames
    end

    csv_string = CSV.generate do |csv|
      processed_data.each do |row|
        csv << row
      end
    end

    filepath = "reports/reports_data/report-#{@report.id}-processed-input.csv"
    FileManager.save_file filepath, csv_string
    @report.processed_input = filepath
  end
end