module ReportGenerator

  def self.weekly
    ends = 1.day.ago.end_of_day
    starts = 6.days.ago(ends).beginning_of_day

    header = ['Username', 'Full Name', 'Website', 'Follows', 'Followed By', 'Media Amount']
    csv_files = {}
    Tag.observed.each do |tag|
      csv_string = CSV.generate do |csv|
        csv << header
        tag.media.where('created_at > ? AND created_at <= ?', starts, ends).to_a.map{|m| m.user}.select{|u|u.website.present?}.uniq.each do |user|
          csv << [user.username, user.full_name, user.website, user.follows, user.followed_by, user.media_amount]
        end
      end
      csv_files[tag.name] = csv_string
    end
    csv_files

    ReportMailer.weekly(csv_files, starts, ends).deliver
  end

end