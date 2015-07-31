class ImportUsersWorker
  include Sidekiq::Worker

  def perform file
    csv = CSV.read(file)
    header = csv.shift
    csv_ids = csv.inject({}){|obj, el| obj[el[1]] = el; obj}

    users = User.where(insta_id: csv.map{|l| l[1]})
    not_exists_users_insta_ids = csv.map{|l| l[1].to_s} - users.map{|u| u.insta_id.to_s}

    not_exists_users_insta_ids.each do |insta_id|
      line = csv_ids[insta_id]
      row = Hash[header.zip(line)]
      row.delete('id')
      row.delete('created_at')
      row.delete('updated_at')
      row['bio'].strip! unless row['bio'].nil?
      row['bio'] = row['bio'][0..254] if row['bio'].present?
      begin
        User.create(row)
      rescue => e
      end
    end

    users.each do |user|
      row = Hash[header.zip(csv_ids[user.insta_id])]

      if row['avg_likes_updated_at'] && user.avg_likes_updated_at.blank?
        user.avg_likes = row['avg_likes']
        user.avg_comments = row['avg_comments']
        user.avg_likes_updated_at = row['avg_likes_updated_at']
      end

      if row['location_updated_at'] && user.location_updated_at.blank? && row['location_country'].present?
        user.location_country = row['location_country']
        user.location_state = row['location_state']
        user.location_city = row['location_city']
        user.location_updated_at = row['location_updated_at']
      end

      if user.changed?
        user.save
      end
    end

    File.delete file rescue false
  end

  def self.spawn
    5.times do
      file = Dir.glob(Rails.root.join('tmp/cache/instaspy320/users*.csv')).map{|file| [file, file.match(/\/users-\d+-(\d+)\.csv$/)[1]]}.sort{|a,b| a[1].to_i <=> b[1].to_i}.shuffle.first.try(:first)
      self.perform_async file
    end
  end
end