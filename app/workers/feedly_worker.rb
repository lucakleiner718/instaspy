class FeedlyWorker

  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform url
    Feedly.process url
  end

end