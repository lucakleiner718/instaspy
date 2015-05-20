require 'open-uri'

class ImportWorker

  include Sidekiq::Worker

  def perform i
    return if Import.where(format: :users, file_id: i).size > 0

    ts = Time.now
    begin
      file = open("http://charts.socialroot.co/reports/users-pack/#{i}.csv")
    rescue OpenURI::HTTPError => e
      return
    end
    data = CSV.parse file.read
    header = data.shift # header

    added = 0
    exists = 0

    cols = header
    cols.slice!(0,2)

    users = User.scoped.in(insta_id: data.map{|r| r[1]}).to_a

    rows = {}
    users.each {|row| rows[row.insta_id] = row}

    data.each do |user_row|
      # t1 = Time.now
      user = rows[user_row[1].to_i]
      if user
        exists += 1
      else
        user = User.new(insta_id: user_row[1])
        added += 1
      end

      cols.each do |column|
        user[column] = user_row[cols.index{|r| r==column}+2] if user[column].nil?
      end
      user.save if user.changed?
    end

    time = (Time.now - ts).round(2)

    Import.create(format: :users, file_id: i, time: time)

    puts "File: #{i} / #{exists}/#{added} / time: #{time}s"
  end

  def self.spawn start: 0, finish: 1600
    (start..finish).each do |i|
      self.perform_async i
    end
  end
end