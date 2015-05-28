namespace :ig do
  desc 'Export instagram logins'
  task :export => :environment do
    output = []
    InstagramAccount.all.each do |ia|
      output << [ia.client_id, ia.client_secret, ia.logins.pluck(:access_token)]
    end
    FileManager.save_file 'export/instagram_account.yml', content: YAML::dump(output)
    puts "#{ENV['FILES_DIR']}/export/instagram_account.yml"
  end
end
