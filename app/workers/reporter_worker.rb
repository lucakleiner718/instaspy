class ReporterWorker
  include Sidekiq::Worker

  def perform method, *args
    Reporter.__send__(method, args)
  end
end