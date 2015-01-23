class MediaWorker
  include Sidekiq::Worker

  # sidekiq_options unqiue: true,
  #                 unique_args: -> (args) { [ args.first ] }

  def perform
    Media.recent_media
  end

  # def perform tag_id
  #   tag = Tag.find(tag_id)
  #   tag.recent_media
  #   # Media.recent_media
  # end
  #
  # def self.spawn
  #   Tag.observed.each do |tag|
  #     self.perform_async tag.id
  #     # tag.recent_media
  #   end
  # end
end