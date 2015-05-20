require 'open-uri'

class ImportTagsWorker

  include Sidekiq::Worker

  def perform i
    return if File.exists?("tmp/cache/import/tag-#{i}")

    ts = Time.now
    begin
      file = open("http://charts.socialroot.co/reports/tags-pack/#{i}.csv")
    rescue OpenURI::HTTPError => e
      return
    end
    data = CSV.parse(file.read).map{|row| row[0].force_encoding('UTF-8').mb_chars.downcase.to_s}
    data.shift # header

    added = 0
    exists = 0

    tags = Tag.in(name: data).pluck(:name)

    not_exists = data - tags

    not_exists.each do |tag|
      Tag.create name: tag
    end

    time = (Time.now - ts).round(2)

    File.write "tmp/cache/import/tag-#{i}", time

    puts "File: #{i} / #{exists}/#{added} / time: #{time}s"
  end

  def self.spawn start: 0, finish: 2000
    (start..finish).each do |i|
      self.perform_async i
    end
  end
end