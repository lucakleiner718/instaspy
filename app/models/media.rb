class Media < ActiveRecord::Base

  has_many :media_tags, dependent: :destroy
  has_many :tags, through: :media_tags
  belongs_to :user

  scope :with_coordinates, -> { where("location_lat is not null AND location_lng is not null") }
  scope :with_country, -> { where("location_country is not null AND location_country != ''") }
  scope :without_location, -> { where("location_lat is null").where(location_present: nil) }
  scope :has_tag, -> (tag_name) { where('tag_names @> ?', "{#{tag_name}}") }

  def location
    loc = []
    loc << self.location_country if self.location_country.present?
    loc << self.location_state if self.location_state.present?
    loc << self.location_city if self.location_city.present?
    loc.join(', ')
  end

  # Update current media info, including publisher and tags
  # @return [Boolean] success save or not
  def update_info!
    return false if self.user && self.user.private?

    start_time = Time.now

    begin
      ic = InstaClient.new
      response = ic.client.media_item(self.insta_id)
    rescue Instagram::BadRequest => e
      if e.message =~ /invalid media id/
        self.destroy
        return false
      elsif e.message =~ /you cannot view this resource/
        self.user.update_info! force: true
        return false
      else
        raise e
      end
    end

    self.set_user response.data['user']
    self.set_data response.data
    self.set_tags response.data['tags']

    save_result = self.save!

    Rails.logger.debug "#{">>".green} Update took #{(Time.now - start_time).to_f.round(2)}s"

    save_result
  end

  def set_data media_item
    if media_item['location']
      self.location_present = true
      self.location_lat = media_item['location']['latitude']
      self.location_lng = media_item['location']['longitude']
      self.location_name = media_item['location']['name']
    else
      self.location_present = false
    end

    self.likes_amount = media_item['likes']['count']
    self.comments_amount = media_item['comments']['count']
    self.link = media_item['link']
    self.created_time = Time.at media_item['created_time'].to_i
    self.image = media_item['images']['standard_resolution']['url']
  end

  def set_user media_item_user, users_found=[]
    user = nil
    user = users_found.select{|el| el.insta_id.to_s == media_item_user['id'].to_s}.first if users_found.size > 0
    user = User.where(insta_id: media_item_user['id']).first_or_initialize unless user

    user.username = media_item_user['username']
    user.full_name = media_item_user['full_name']

    user = user.must_save if user.changed?
    self.user_id = user.id
  end

  def set_tags tags_names, tags_found=[], is_new=false
    unless tags_found
      tags_found = Tag.where(id: self.media_tags.pluck(:tag_id))
    end

    tags_names.map!(&:downcase)

    find_more = [].concat tags_names
    if tags_found.size > 0
      find_more -= tags_found.map{|el| el.name.downcase}
    end

    if find_more.size > 0
      found = Tag.where(name: find_more).to_a
      if found.size > 0
        tags_found.concat found
      end
      if found.size < find_more.size
        names = find_more - found.map(&:name)
        names.each do |tag_name|
          begin
            tags_found << Tag.create(name: tag_name)
          rescue ActiveRecord::RecordNotUnique
            tags_found << Tag.find_by_name(tag_name)
          end
        end
      end
    end

    tags_list = []
    if tags_found.size > 0
      tags_list = tags_names.map do |tag_name|
        tags_found.select{|el| el.name.downcase == tag_name.downcase}.first
      end
    end

    media_tags_connections = []
    unless is_new
      media_tags_connections = MediaTag.where(media_id: self.id).pluck(:tag_id)
      if tags_list.size > 0
        deleted_tags = media_tags_connections - tags_list.map(&:id)
        if deleted_tags.size > 0
          MediaTag.where(media_id: self.id, tag_id: deleted_tags).destroy_all
        end
      end
    end

    media_tag_insert = tags_list.map(&:id) - media_tags_connections
    if media_tag_insert.size > 0
      begin
        MediaTag.connection.execute("INSERT INTO media_tags (media_id, tag_id) VALUES #{media_tag_insert.map{|tag_id| "(#{self.id}, #{tag_id})"}.join(', ')}")
      rescue ActiveRecord::RecordNotUnique => e
        self.tags = tags_list
      end
    end

    self.tag_names = tags_names
  end

  def update_location! *args
    return false if self.location_lat.blank? || self.location_lng.blank?

    gl = Geolocation.new self.location_lat, self.location_lng, self.id
    location = gl.get_location *args

    return false unless location

    self.location_country = location[:country]
    self.location_state = location[:state]
    self.location_city = location[:city]

    self.save! if self.changed?
  end

  def self.get_by_location lat, lng, *args
    options = args.extract_options!

    min_timestamp = nil
    max_timestamp = nil

    total_added = 0
    options[:total_limit] ||= 2_000
    options[:distance] ||= 100

    while true
      ic = InstaClient.new
      media_list = ic.client.media_search(lat, lng, distance: options[:distance], min_timestamp: min_timestamp, max_timestamp: max_timestamp, count: 100)

      added = 0
      avg_created_time = 0
      added_media = []

      media_list.data.each do |media_item|
        media = Media.where(insta_id: media_item['id']).first_or_initialize

        media.set_user media_item['user']
        media.set_data media_item

        if media.new_record?
          added += 1
          added_media << media
        end

        media.save! unless media.new_record? && Media.where(insta_id: media_item['id']).size == 1

        media.set_tags media_item['tags']

        avg_created_time += media['created_time'].to_i
      end

      total_added += added

      break if media_list.data.size == 0

      avg_created_time = avg_created_time / media_list.data.size

      logger.debug "#{avg_created_time} / #{Time.at avg_created_time} / added: #{added}"

      if options[:without_location].blank?
        added_media.each { |media| media.update_location! }
      end

      if options[:created_from].present? && Time.at(avg_created_time) > options[:created_from]
        max_timestamp = media_list.data.last.created_time
      elsif options[:ignore_exists] || added.to_f / media_list.data.size > 0.1
        max_timestamp = media_list.data.last.created_time
      elsif total_added >= options[:total_limit]
        break
      else
        break
      end
    end
  end

  def self.get id
    Media.where(insta_id: id).first
  end

  def get_country
    coords = [self.location_lat, self.location_lng]
    g = RGeo::Geos::CAPIFactory.new
    point = g.point coords[1], coords[0]
    filename = 'vendor/TM_WORLD_BORDERS-0.3/TM_WORLD_BORDERS-0.3.shp'
    shapes = RGeo::Shapefile::Reader.open(filename)
    shapes.each do |shape|
      puts "#{shape.attributes['NAME']}"
      if shape.geometry.contains? point
        return shape.attributes
      end
    end
    false
  end

  private

  def self.delete_old amount=100_000
    split_size = 10_000
    (amount/split_size.to_f).ceil.times do |i|
      ids = Media.order(id: :asc).where('created_at < :time AND created_time < :time', time: 2.months.ago).limit(split_size).offset(split_size*i).pluck(:id)
      ActiveRecord::Base.transaction do
        Media.connection.execute("DELETE FROM media WHERE id IN (#{ids.join(',')})")
        Media.connection.execute("DELETE FROM media_tags WHERE media_id IN (#{ids.join(',')})")
      end
    end
  end

end
