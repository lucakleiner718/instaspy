[
  ['1580f11e7be6444cbb6e941dcd7b8c6c', '43662ac3db0143ccb83385f783bff770'],
  ['cb5cabf8bfa148478a8eb0439c138255', '37eda1661ae840f2bd7ce74bfdee2e2f'],
  ].each do |r|
  InstagramAccount.where(client_id: r[0], client_secret: r[1]).first_or_create(redirect_uri: (r[2] || 'http://107.170.110.156/oauth/signin'))
end