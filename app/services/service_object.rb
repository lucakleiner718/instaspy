class ServiceObject

  def self.perform *args
    instance = self.new
    instance.perform *args
  end

  def perform

  end

  protected

  def logger
    Rails.logger
  end

end