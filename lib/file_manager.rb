require 'open-uri'

module FileManager

  def self.save_file filepath, content
    # if Rails.env.production?
      connection = Fog::Storage.new({
        provider:              'AWS',
        aws_access_key_id:     ENV['AWS_ACCESS_KEY'],
        aws_secret_access_key: ENV['AWS_SECRET_KEY'],
        # persistent:            true
      })

      dir = connection.directories.new(
        key: "instaspy-files/#{File.dirname(filepath)}",
      )

      file = dir.files.create(
        key: File.basename(filepath),
        body: content,
        public: true
      )

      true if file
    # else
    #   # Dir.mkdir(Rails.root.join("public/reports/reports_data")) unless Dir.exist?(Rails.root.join("public/reports/reports_data"))
    #   File.write(Rails.root.join("public/reports/reports_data/report-#{@report.id}-original-input.csv"), csv_string)
    # end

  end

  def self.read_file filepath
    open("#{ENV['FILES_DIR']}/#{filepath}").read
  end

end