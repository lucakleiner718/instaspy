require 'open-uri'

class ImportFollowersWorker

  include Sidekiq::Worker

  def perform i
    return if Import.where(format: :followers, file_id: i).size > 0

    ts = Time.now
    begin
      file = open("http://charts.socialroot.co/reports/followers-pack/#{i}.csv")
    rescue OpenURI::HTTPError => e
      return
    end
    data = CSV.parse file.read
    header = data.shift # header

    insta_ids = data.inject([]){|ar, el| ar << el[0]; ar << el[1]; ar}.uniq.map(&:to_i)

    users = []
    insta_ids.in_groups_of(10_000, false) do |group|
      users.concat User.where(insta_id: group).pluck(:id, :insta_id)
    end

    not_exists = insta_ids - users.map(&:last)
    not_exists.each do |insta_id|
      u = User.create(insta_id: insta_id)
      users << [u.id, u.insta_id]
    end

    rows = users.inject({}){ |obj, row| obj[row[1]] = row[0]; obj }

    data.each do |follower_row|
      user_id = rows[follower_row[0].to_i]
      follower_id = rows[follower_row[1].to_i]
      fol = Follower.where(user_id: user_id, follower_id: follower_id).first_or_initialize
      fol.followed_at = DateTime.parse(follower_row[2]) if follower_row[2].present?
      fol.save if fol.changed?
    end

    time = (Time.now - ts).round(2)

    Import.create(format: :followers, file_id: i, time: time)

    puts "File: #{i} / time: #{time}s"
  end

  def self.spawn start: 0, finish: 350
    (start..finish).each do |i|
      self.perform_async i
    end
  end
end