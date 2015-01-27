class Media < ActiveRecord::Base

  has_and_belongs_to_many :tags
  belongs_to :user

  def self.recent_media
    tag = Tag.observed.where('observed_tags.media_updated_at < ? or observed_tags.media_updated_at is null', 1.minute.ago).order('observed_tags.media_updated_at asc').first
    if tag.present?
      tag.observed_tag.update_column :media_updated_at, Time.now
      tag.recent_media
    end
  end

  def self.report starts=nil, ends=nil
    ends ||= 1.day.ago.end_of_day
    starts ||= 6.days.ago(ends).beginning_of_day

    header = ['Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followed By', 'Media Amount', 'Added to Instaspy']
    csv_files = {}
    Tag.exportable.each do |tag|
      users_ids = tag.media.where('created_at > ? AND created_at <= ?', starts, ends).pluck(:user_id).uniq
      users = User.where(id: users_ids).where("website is not null AND website != ''")
                .where('created_at >= ?', starts).where('created_at <= ?', ends)
                .select([:id, :username, :full_name, :website, :bio, :follows, :followed_by, :media_amount, :created_at])

      csv_string = CSV.generate do |csv|
        csv << header
        users.find_each do |user|
          csv << [user.username, user.full_name, user.website, user.bio, user.follows, user.followed_by, user.media_amount, user.created_at.strftime('%m/%d/%Y')]
        end
      end
      csv_files[tag.name] = csv_string
    end
    csv_files

    ReportMailer.weekly(csv_files, starts, ends).deliver
  end

  # delete all media oldest than 4 weeks
  def self.delete_old
    Media.where('created_time < ?', 4.weeks.ago).destroy_all
  end

end
