class FolloweesReport

  def initialize username
    @user = User.add_by_username username
  end

  # regularly update latest followers of specified account
  def get_new
    @user.update_followees
  end

  def reload
    @user.update_followees reload: true
  end

  def send_full_report
    FolloweesReportMailer.full(@user).deliver
  end

  def send_weekly_report
    FolloweesReportMailer.weekly(@user).deliver
  end

  def self.send_full_report user_arr
    users = User.where(username: user_arr).to_a
    FolloweesReportMailer.full(users).deliver
  end

  def self.get_new usernames
    usernames.each do |username|
      fr = self.new username
      fr.get_new
    end
  end

end