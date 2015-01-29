class UsersEmails

  def self.check_all
    email_regex = /([\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+)/
    emails = []

    User.find_each(batch_size: 5000) do |user|
      next if user.bio.blank?
      m = user.bio.match(email_regex)
      if m && m[1]
        emails << { user: user, email: m[1].downcase.sub(/^[\.\-\_]+/, '') }
      end
    end

    GeneralMailer.users_emails(emails).deliver
  end

end