class TagMediaCounterWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical

  def perform tag_id, action='+'
    connection = ActiveRecord::Base.connection
    connection.execute("update tags set media_count=media_count#{action.in?(['+', '-']) ? action : '+'}1 where id=#{tag_id.to_i}")
  end
end