class FollowersReport

  def initialize username
    @user = User.add_by_username username
  end

  def get_new
    @user.update_followers
  end

  def reload
    @user.update_followers reload: true
  end

  def send_report
    FollowersReportMailer.user(@user).deliver
  end

end