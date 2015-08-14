require 'open-uri'

module FileManager

  class << self

    def file_url filepath
      if Rails.env.production?
        "#{ENV['FILES_DIR']}/#{filepath}"
      else
        "http://localhost:3000/#{filepath}"
      end
    end

    def save_file filepath, content: nil, file: nil
      if Rails.env.production?
        save_to_s3 filepath, content: content, file: file
      else
        save_to_fs filepath, content: content, file: file
      end
    end

    def read_file filepath
      if Rails.env.production?
        read_from_s3 filepath
      else
        read_from_fs filepath
      end
    end

    def delete_file filepath
      if Rails.env.production?
        delete_from_s3 filepath
      else
        delete_from_fs filepath
      end
    end

    def open_file filepath, &block
      tmp = "tmp/#{File.basename(filepath)}-#{Time.now.to_i}"
      File.open tmp, block
      save_file filepath, File.read(tmp)
    end

    def save_to_fs filepath, content: nil, file: nil
      full_path = Rails.root.join('public', filepath)
      FileUtils.mkdir_p File.dirname(full_path)

      if content
        File.write full_path, content
      elsif file
        FileUtils.mv(file, full_path)
      end
    end

    def read_from_fs filepath
      File.read Rails.root.join('public', filepath)
    end

    def delete_from_fs filepath
      File.delete Rails.root.join('public', filepath)
    end

    def save_to_s3 filepath, content: nil, file: nil
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
        body: content ? content : File.open(file),
        public: true
      )

      true if file
      # else
      #   # Dir.mkdir(Rails.root.join("public/reports/reports_data")) unless Dir.exist?(Rails.root.join("public/reports/reports_data"))
      #   File.write(Rails.root.join("public/reports/reports_data/report-#{@report.id}-original-input.csv"), csv_string)
      # end

    end

    def read_from_s3 filepath
      open("#{ENV['FILES_DIR']}/#{filepath}").read
    end

    def delete_from_s3 filepath
      connection = Fog::Storage.new({
          provider:              'AWS',
          aws_access_key_id:     ENV['AWS_ACCESS_KEY'],
          aws_secret_access_key: ENV['AWS_SECRET_KEY'],
          # persistent:            true
        })

      dir = connection.directories.new(
        key: "instaspy-files/#{File.dirname(filepath)}",
      )

      file = dir.files.head(File.basename(filepath))

      file.destroy if file
    end

  end

end