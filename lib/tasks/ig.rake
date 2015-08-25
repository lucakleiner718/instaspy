namespace :ig do
  desc 'Export instagram logins'
  task :export => :environment do
    output = []
    InstagramAccount.all.each do |ia|
      output << [ia.client_id, ia.client_secret, ia.logins.pluck(:access_token)]
    end
    FileManager.save_file 'export/instagram_account.yml', content: YAML::dump(output)
    puts FileManager.file_url "export/instagram_account.yml"
  end

  desc 'Import instagram logins'
  task :import => :environment do
    require 'open-uri'
    ar = YAML.load open('https://s3.amazonaws.com/instaspy-files/export/instagram_account.yml').read
    ar.each do |row|
      ia = InstagramAccount.where(client_id: row[0], client_secret: row[1]).first_or_create
      row[2].each do |row|
        InstagramLogin.where(account_id: ia.id, access_token: row).first_or_create
      end
    end
  end
end
