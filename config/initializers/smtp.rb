ActionMailer::Base.smtp_settings = {
  address: 'smtp.yandex.ru',
  port: 25,
  user_name: "dev@antonzaytsev.com",
  password: "DEVantonZPassword1",
  authentication: :plain,
  enable_starttls_auto: true
}