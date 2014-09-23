class Media < ActiveRecord::Base

  has_and_belongs_to_many :tags
  belongs_to :user

  def self.recent_media
    Tag.observed.each do |tag|
      tag.recent_media
    end
  end

  def self.report starts=nil, ends=nil
    ends ||= 1.day.ago.end_of_day
    starts ||= 6.days.ago(ends).beginning_of_day

    header = ['Username', 'Full Name', 'Website', 'Follows', 'Followed By', 'Media Amount']
    csv_files = {}
    Tag.where(grabs_users_csv: true).each do |tag|
      users_ids = tag.media.where('created_at > ? AND created_at <= ?', starts, ends).pluck(:user_id).uniq
      users = User.where(id: users_ids).where("website is not null AND website != ''")

      csv_string = CSV.generate do |csv|
        csv << header
        users.find_each do |user|
          csv << [user.username, user.full_name, user.website, user.follows, user.followed_by, user.media_amount]
        end
      end
      csv_files[tag.name] = csv_string
    end
    csv_files

    ReportMailer.weekly(csv_files, starts, ends).deliver
  end

  def self.delete_old
    Media.where('created_time < ?', 2.weeks.ago).destroy_all
  end

end
