class BSON::ObjectId
  def to_json(*args)
    "\"#{to_s}\""
  end
end