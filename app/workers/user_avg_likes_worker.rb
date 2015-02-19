class UserAvgLikesWorker

  include Sidekiq::Worker

  def perform users_ids
    User.where(id: users_ids).each do |user|
      media = user.media

      if media.size > 0
        likes_total = 0
        media_amount = 0

        media.each do |media_item|
          if media_item.updated_at - media_item.created_time < 3.days
            media_item.update_info!
          end

          if media_item.likes_amount.present?
            likes_total += media_item.likes_amount
            media_amount += 1
          end
        end

        user.avg_likes = likes_total / media_amount if media_amount > 0
        user.avg_likes_updated_at = Time.now
        user.save
      end
    end
  end

  def self.spawn in_batch=100
    User.where('followed_by is null OR followed_by > 1000')
      .where('avg_likes_updated_at is null OR avg_likes_updated_at < ?', 1.month.ago)
      .order(created_at: :desc).select(:id).find_in_batches(batch_size: in_batch) do |users_group|

      self.perform_async users_group.map(&:id)
    end
  end
end