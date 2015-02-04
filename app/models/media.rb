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

    header = ['Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followed By', 'Media Amount', 'Added to Instaspy', 'Media URL', 'Media likes', 'Media comments']
    csv_files = {}
    Tag.exportable.each do |tag|
      users_ids = tag.media.where('created_at > ? AND created_at <= ?', starts, ends).pluck(:user_id).uniq
      users = User.where(id: users_ids).where("website is not null AND website != ''")
                .where('created_at >= ?', starts).where('created_at <= ?', ends)
                .select([:id, :username, :full_name, :website, :bio, :follows, :followed_by, :media_amount, :created_at])

      csv_string = CSV.generate do |csv|
        csv << header
        users.find_each do |user|
          media = user.media.joins(:tags).where('tags.name = ?', tag.name).order(created_at: :desc).where('created_time < ?', 1.day.ago).first
          media = user.media.joins(:tags).where('tags.name = ?', tag.name).order(created_at: :desc).first if media.blank?
          # if somehow we don't have media
          next unless media
          media.update! if media.updated_at < 3.days.ago || media.likes_amount.blank? || media.comments_amount.blank? || media.link.blank?
          csv << [
            user.username, user.full_name, user.website, user.bio, user.follows, user.followed_by, user.media_amount,
            user.created_at.strftime('%m/%d/%Y'), media.link, media.likes_amount, media.comments_amount
          ]
        end
      end
      csv_files[tag.name] = csv_string
    end
    csv_files

    ReportMailer.weekly(csv_files, starts, ends).deliver
  end

  # delete all media oldest than 12 weeks
  def self.delete_old frame=12.weeks
    Media.where('created_time < ?', frame.ago).destroy_all
  end

  def update!
    client = InstaClient.new.client

    response = client.media_item(self.insta_id)

    media_item = response.data

    user = User.where(insta_id: media_item['user']['id']).first_or_initialize
    if user.new_record?
      # with same username as we want to create
      user2 = User.where(username: media_item['user']['username']).first_or_initialize
      unless user2.new_record?
        user = user2
        user.insta_id = media_item['user']['id']
      end
    end
    user.username = media_item['user']['username']
    user.full_name = media_item['user']['full_name']
    user.save
    self.user_id = user.id

    self.likes_amount = media_item['likes']['count']
    self.comments_amount = media_item['comments']['count']
    self.link = media_item['link']
    self.created_time = Time.at media_item['created_time'].to_i

    tags = []
    media_item['tags'].each do |tag_name|
      tags << Tag.unscoped.where(name: tag_name).first_or_create
    end
    self.tags = tags

    self.save
  end

end
