class ReportsController < ApplicationController
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
end
