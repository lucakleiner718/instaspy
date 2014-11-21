class FollowersReport

  def initialize username
    @user = User.add_by_username username
  end

  # regularly update latest followers of specified account
  def get_new
    @user.update_followers
  end

  def reload
    @user.update_followers reload: true
  end

  def send_full_report
    FollowersReportMailer.full(@user).deliver
  end

  def send_weekly_report
    FollowersReportMailer.weekly(@user).deliver
  end

end