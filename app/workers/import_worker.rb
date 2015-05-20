require 'open-uri'

class ImportWorker

  include Sidekiq::Worker

  def perform nums
    nums = [nums] if nums.is_a? Integer

    nums.each do |i|
      next if File.exists?("tmp/cache/import/#{i}")

      ts = Time.now
      begin
        file = open("http://charts.socialroot.co/reports/users-pack/#{i}.csv")
      rescue OpenURI::HTTPError => e
        next
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

        # puts "#{exists}/#{added} / Time: #{(Time.now - t1).round(2)}s"
      end

      time = (Time.now - ts).round(2)

      File.write "tmp/cache/import/#{i}", time

      puts "File: #{i} / #{exists}/#{added} / time: #{time}s"
    end
  end

  def self.spawn start: 0, finish: 1600
    (start..finish).each do |i|
      self.perform_async i
    end
  end
end