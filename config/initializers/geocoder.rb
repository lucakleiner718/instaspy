Geocoder.configure(
  timeout:      10,
  lookup:       :yandex,

  bing: {
    api_key: 'AreNey4-B-i5NhpxcZJg3hPEl_Gta4qp2vTlShk5Bc4qt2FXq9vGlgosts-Dzq1l',
  },
  here: {
    api_key: ['XaB0y63AcGfc5ZtIrbde', 'ZrESX_vdjfU-LmMli8zopg'],
  },
  opencagedata: {
    api_key: 'f1fa119e5e9651ccfb690481681f143c'
  },
  language:     :en,
  use_https: true,

  # exceptions that should not be rescued by default
  # (if you want to implement custom error handling);
  # supports SocketError and TimeoutError
  # :always_raise => [],
  :always_raise => :all
)
