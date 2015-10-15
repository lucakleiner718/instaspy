class FeedlyWorker

  include Sidekiq::Worker

  sidekiq_options unique: :until_executed, unique_args: -> (args) { [ args.first ] }

  def perform url
    Feedly.process url
  end

end