root = File.dirname(__FILE__) + '/..'

God.watch do |w|
  w.env = { 'RAILS_ROOT' => root,
            'RAILS_ENV' => "production" }
  w.dir           = root
  w.name          = "puma"
  w.interval      = 60.seconds
  w.pid_file      = "#{root}/tmp/pids/puma.pid"
  w.start         = "bundle exec puma --pidfile #{w.pid_file}"
  w.stop          = "kill -s TERM $(cat #{w.pid_file})"
  w.restart       = "kill -s USR2 $(cat #{w.pid_file})"
  w.log           = "#{root}/log/god.puma.log"
  w.start_grace   = 20.seconds
  w.restart_grace = 20.seconds

  w.behavior(:clean_pid_file)

  # When to start?
  w.start_if do |start|
    start.condition(:process_running) do |c|
      # We want to check if deamon is running every ten seconds
      # and start it if itsn't running
      c.interval = 10.seconds
      c.running = false
    end
  end

  # When to restart a running deamon?
  w.restart_if do |restart|
    restart.condition(:memory_usage) do |c|
      # Pick five memory usage at different times
      # if three of them are above memory limit (100Mb)
      # then we restart the deamon
      c.above = 100.megabytes
      c.times = [3, 5]
    end

    restart.condition(:cpu_usage) do |c|
      # Restart deamon if cpu usage goes
      # above 90% at least five times
      c.above = 90.percent
      c.times = 5
    end
  end

  w.lifecycle do |on|
    # Handle edge cases where deamon
    # can't start for some reason
    on.condition(:flapping) do |c|
      c.to_state = [:start, :restart] # If God tries to start or restart
      c.times = 5                     # five times
      c.within = 5.minute             # within five minutes
      c.transition = :unmonitored     # we want to stop monitoring
      c.retry_in = 10.minutes         # for 10 minutes and monitor again
      c.retry_times = 5               # we'll loop over this five times
      c.retry_within = 2.hours        # and give up if flapping occured five times in two hours
    end
  end
end

God.watch do |w|
  w.env = { 'RAILS_ROOT' => root,
            'RAILS_ENV' => "production" }
  w.dir           = root
  w.name          = "sidekiq"
  w.interval      = 60.seconds
  w.pid_file      = "#{root}/tmp/pids/sidekiq.pid"
  w.start         = "~/.rvm/bin/rvm 2.1.1@instaspy do sidekiq -C #{root}/config/sidekiq.yml -r #{root}/config/environment.rb"
  w.stop          = "kill -s TERM $(cat #{w.pid_file})"
  w.restart       = "kill -s USR2 $(cat #{w.pid_file})"
  w.log           = "#{root}/log/sidekiq.log"
  w.start_grace   = 20.seconds
  w.restart_grace = 20.seconds

  # w.start = "/home/app/.rvm/gems/ruby-2.1.1@instaspy/bin/ruby -f #{rails_root}/ sidekiq -c 25 -q worker,15 -q distributor,5"

  # w.keepalive

  w.behavior(:clean_pid_file)

  # When to start?
  w.start_if do |start|
    start.condition(:process_running) do |c|
      # We want to check if deamon is running every ten seconds
      # and start it if itsn't running
      c.interval = 10.seconds
      c.running = false
    end
  end

  # When to restart a running deamon?
  w.restart_if do |restart|
    restart.condition(:memory_usage) do |c|
      # Pick five memory usage at different times
      # if three of them are above memory limit (100Mb)
      # then we restart the deamon
      c.above = 100.megabytes
      c.times = [3, 5]
    end

    restart.condition(:cpu_usage) do |c|
      # Restart deamon if cpu usage goes
      # above 90% at least five times
      c.above = 90.percent
      c.times = 5
    end
  end

  w.lifecycle do |on|
    # Handle edge cases where deamon
    # can't start for some reason
    on.condition(:flapping) do |c|
      c.to_state = [:start, :restart] # If God tries to start or restart
      c.times = 5                     # five times
      c.within = 5.minute             # within five minutes
      c.transition = :unmonitored     # we want to stop monitoring
      c.retry_in = 10.minutes         # for 10 minutes and monitor again
      c.retry_times = 5               # we'll loop over this five times
      c.retry_within = 2.hours        # and give up if flapping occured five times in two hours
    end
  end

  # w.transition(:up, :start) do |on|
  #   on.condition(:process_exits) do |c|
  #     c.notify = 'anton'
  #   end
  # end
end

God.contact(:email) do |c|
  c.name = 'anton'
  c.group = 'developers'
  c.to_email = 'dev@antonzaytsev.com'
end