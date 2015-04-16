class FeedlyWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def expiration
    @expiration ||= 60*60*24*7
  end

  def perform url
    Feedly.process url
  end
end