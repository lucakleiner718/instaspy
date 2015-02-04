class BackupWorker
  include Sidekiq::Worker

  def perform
    require 's3-mysql-backup'

    db_config = Rails.configuration.database_configuration[Rails.env]

    S3MysqlBackup.new(db_config['database'], {
        # where to store the local backups, default is ~/s3_mysql_backups
        # backup_dir: '~/instaspy/shared/backups',
        backup_dir: Rails.root.join('tmp'),
        # OPTIONAL, where to store the remote backups, default is the root of your s3_bucket
        # remote_dir: '/path/to/remote/backups',

        # s3_access_key_id      your Amazon S3 access_key_id
        s3_access_key_id: 'AKIAIMCZKJUJC6XMYGJA',
        # your Amazon S3 secret_access_key
        s3_secret_access_key: 'llZw1ZojTvHVTdlNA7O/GxbGZJCD4CZOZVVvltP8',
        # your Amazon S3 bucket for the backups
        s3_bucket: 'instaspy',
        # OPTIONAL, your non-Amazon S3-compatible server
        # s3_server: '',

        # OPTIONAL, your mysql host name
        # dump_host: '',
        # the database user for mysqldump
        dump_user: db_config['username'],
        # the password for the dump user
        dump_pass: db_config['password'],

        # where to send the backup summary email
        # mail_to: '',

        # Mail credentials
        # mail_user: me@example.com
        # mail_pass: example_password
        # mail_from: noreply@example.com  # OPTIONAL, defaults to mail_user
        # mail_domain: smtp.example.com   # OPTIONAL, defaults to: smtp.gmail.com
        # mail_port: 587                  # OPTIONAL, defaults to: 587
        # mail_authentication: login      # OPTIONAL, defaults to: :login
        # mail_start_tls: true            # OPTIONAL, defaults to: true
      }).run
  end
end