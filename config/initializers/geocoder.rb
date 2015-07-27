Geocoder.configure(
  timeout:      10,
  lookup:       :bing,
  bing: {
    api_key: 'AreNey4-B-i5NhpxcZJg3hPEl_Gta4qp2vTlShk5Bc4qt2FXq9vGlgosts-Dzq1l',
  },
  here: {
    api_key: ['XaB0y63AcGfc5ZtIrbde', 'ZrESX_vdjfU-LmMli8zopg'],
  },
  opencagedata: {
    api_key: 'f1fa119e5e9651ccfb690481681f143c'
  },
  #
  # Geocoder::Configuration.api_key = 'd5dd99546055d0d5d6be0de04446595dd5bb365'
  language:     :en,
  # :use_https    => false,       # use HTTPS for lookup requests? (if supported)
  # :http_proxy   => nil,         # HTTP proxy server (user:pass@host:port)
  # :https_proxy  => nil,         # HTTPS proxy server (user:pass@host:port)
  # :api_key      => nil,         # API key for geocoding service
  # :cache        => nil,         # cache object (must respond to #[], #[]=, and #keys)
  # :cache_prefix => "geocoder:", # prefix (string) to use for all cache keys

  # exceptions that should not be rescued by default
  # (if you want to implement custom error handling);
  # supports SocketError and TimeoutError
  # :always_raise => [],
  :always_raise => :all,

  # calculation options
  # :units     => :mi,       # :km for kilometers or :mi for miles
  # :distances => :linear    # :spherical or :linear

  cache: Redis.new
)
