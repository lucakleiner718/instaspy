class UsersEmails

  def self.check_all
    email_regex = /([\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+)/
    emails = []

    User.each do |user|
      next if user.bio.blank?
      m = user.bio.match(email_regex)
      if m && m[1]
        user.email = m[1].downcase.sub(/^[\.\-\_]+/, '')
        user.save
        emails << user
      elsif user.email.present?
        emails << user
      end
    end

    GeneralMailer.users_emails(emails).deliver
  end

end