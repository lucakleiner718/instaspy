God.pid_file_directory = File.expand_path(File.join(File.dirname(__FILE__),'..')) + '/tmp/pids'
CURRENT_DIR = File.expand_path(File.join(File.dirname(__FILE__),'..'))

God::Contacts::Email.defaults do |d|
  d.from_email = "dev@antonzaytsev.com"
  d.from_name = 'God'
  d.delivery_method = :smtp
  d.server_host = 'smtp.yandex.ru'
  d.server_port = 25
  d.server_user = "dev@antonzaytsev.com"
  d.server_password = "DEVantonZPassword1"
  d.server_auth = :plain
end

God.contact(:email) do |c|
  c.name = 'Anton'
  c.group = 'developers'
  c.to_email = 'dev@antonzaytsev.com'
end

God.watch do |w|
  w.name = 'clockwork'
  w.interval = 30.seconds
  w.env = {
    'RAILS_ENV' => :development
  }
  # w.uid = 'user'
  # w.gid = 'user'
  w.dir = CURRENT_DIR
  w.start = "bundle exec clockwork config/clock.rb"
  w.start_grace = 10.seconds
  w.log = File.expand_path(File.join(File.dirname(__FILE__), '..','log','god-clockwork.log'))
  w.keepalive
end

God.watch do |w|
  w.name = "sidekiq"
  w.interval = 30.seconds
  w.env = {
    'RAILS_ENV' => :development,
  }
  # w.uid = 'user'
  # w.gid = 'user'
  w.dir = CURRENT_DIR
  w.start = "bundle exec sidekiq -C config/sidekiq.yml"
  w.start_grace = 10.seconds
  w.log = File.expand_path(File.join(File.dirname(__FILE__), '..','log',"god-sidekiq.log"))
  w.keepalive

  # w.restart_if do |restart|
  #   # restart.condition(:cpu_usage) do |c|
  #   #   c.above = 50.percent
  #   #   c.times = 5
  #   # end
  #   restart.condition(:memory_usage) do |c|
  #     c.above = 1000.megabytes
  #     c.times = [3, 5] # 3 out of 5 intervals
  #   end
  # end

  w.transition(:up, :start) do |on|
    on.condition(:process_exits) do |c|
      c.notify = 'Anton'
    end
  end
end
