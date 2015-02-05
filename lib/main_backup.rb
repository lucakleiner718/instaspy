# encoding: utf-8

db_config = YAML.load_file('/home/app/instaspy/shared/config/database.yml')['production']
app_config = YAML.load_file('/home/app/instaspy/shared/config/application.yml')

##
# Backup Generated: main_backup
# Once configured, you can run the backup with the following command:
#
# $ backup perform -t main_backup [-c <path_to_configuration_file>]
#
Backup::Model.new(:main_backup, 'Description for main_backup') do
  ##
  # Split [Splitter]
  #
  # Split the backup file in to chunks of 250 megabytes
  # if the backup file size exceeds 250 megabytes
  #
  split_into_chunks_of 250

  ##
  # MySQL [Database]
  #
  database MySQL do |db|
    # To dump all databases, set `db.name = :all` (or leave blank)
    db.name               = db_config['database']
    db.username           = db_config['username']
    db.password           = db_config['password']
    db.host               = "localhost"
    db.port               = 3306
    db.socket             = "/tmp/mysql.sock"
    # Note: when using `skip_tables` with the `db.name = :all` option,
    # table names should be prefixed with a database name.
    # e.g. ["db_name.table_to_skip", ...]
    # db.skip_tables        = ["skip", "these", "tables"]
    # db.only_tables        = ["only", "these", "tables"]
    # db.additional_options = ["--quick", "--single-transaction"]
  end

  ##
  # Amazon Simple Storage Service [Storage]
  #
  # Available Regions:
  #
  #  - ap-northeast-1
  #  - ap-southeast-1
  #  - eu-west-1
  #  - us-east-1
  #  - us-west-1
  #
  store_with S3 do |s3|
    s3.access_key_id     = "AKIAJ6XWWEHFUGLW7ATQ"
    s3.secret_access_key = "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"
    s3.region            = "us-west-2"
    s3.bucket            = "instaspy-backups"
    # s3.path              = "/path/to/my/backups"
    s3.keep              = 30
  end

  ##
  # Gzip [Compressor]
  #
  compress_with Gzip

  ##
  # Mail [Notifier]
  #
  # The default delivery method for Mail Notifiers is 'SMTP'.
  # See the Wiki for other delivery options.
  # https://github.com/meskyanichi/backup/wiki/Notifiers
  #
  notify_by Mail do |mail|
    mail.on_success           = false
    mail.on_warning           = true
    mail.on_failure           = true

    mail.from                 = "dev@antonzaytsev.com"
    mail.to                   = "me@antonzaytsev.com"
    mail.address              = 'smtp.yandex.ru'
    mail.port                 = 25
    # mail.domain               = "your.host.name"
    mail.user_name            = "dev@antonzaytsev.com"
    mail.password             = "DEVantonZPassword1"
    mail.authentication       = "plain"
    mail.encryption           = :starttls
  end

end
