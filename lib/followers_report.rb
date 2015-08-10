class FollowersReport

  def initialize username
    @user = User.get_by_username username
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


  def get_new_follows
    @user.update_followees
  end

  def reload_follows
    @user.update_followees reload: true
  end

  def self.track
    TrackUser.where(followers: true).each do |track_user|
      report = FollowersReport.new track_user.user.username
      report.get_new
    end
  end

  def self.send_weekly_report
    FollowersReportMailer.weekly(User.where(id: TrackUser.where(followers: true).pluck(:user_id)).to_a).deliver
  end

end
