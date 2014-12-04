# %w|luckyfabb fashionblogger fashionblogger_de fashionbloggeritalia liketkit|.each do |tag_name|
#   Tag.where(name: tag_name).first_or_create(observed: true)
# end