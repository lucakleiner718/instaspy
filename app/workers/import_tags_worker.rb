require 'open-uri'

class ImportTagsWorker

  include Sidekiq::Worker

  def perform nums
    nums = [nums] if nums.is_a? Integer

    nums.each do |i|
      next if File.exists?("tmp/cache/import/tag-#{i}")

      ts = Time.now
      begin
        file = open("http://charts.socialroot.co/reports/tags-pack/#{i}.csv")
      rescue OpenURI::HTTPError => e
        next
      end
      data = CSV.parse(file.read).map{|row| row[0].force_encoding('UTF-8').mb_chars.downcase.to_s}
      data.shift # header

      added = 0
      exists = 0

      tags = Tag.in(name: data).pluck(:name)

      not_exists = data - tags

      not_exists.each do |tag|
        Tag.create name:  tag
      end

      time = (Time.now - ts).round(2)

      File.write "tmp/cache/import/tag-#{i}", time

      puts "File: #{i} / #{exists}/#{added} / time: #{time}s"
    end
  end

  def self.spawn start=0
    (start..2000).each do |i|
      self.perform_async i
    end
  end
end