class MediaUpdateWorker
  include Sidekiq::Worker

  sidekiq_options unique: :until_and_while_executing, unique_args: -> (args) { [ args.first ] }

  def perform media_id
    media_item = Media.find media_id
    media_item.update_info!
  end

end