class TagUserLocationWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform tag_name
    Reporter.user_locations tag_name
  end

  def self.spawn
    tags = "SamanthaWills,jacquieaiche,8otherreasons,luvaj,jenniferzeuner,jatribe,lionetteny,ALEXMIKA,ALEXMIKAXBETCHES,AmberSceats,NatalieBJewelry,nbj,eddieborgo,marthacalvo,joolz,wanderlustandco,vanessamooney,mestack,matterialfix,margaretelizabeth,lorenhope,jsobsess,baublebar,jewelmint,charmandchain,maxandchloe,JEWELIQ,AlphaXiDelta,AlphaChiOmega,DeltaGamma,AlphaPhi,KappaKappaGamma,KappaAlphaTheta,PiBetaPhi,ChiOmega,SigmaKappa,AlphaOmicronPi,ZetaTauAlpha,AlphaDeltaPi,PhiMu,DeltaZeta,KappaDelta,AlphaSigmaTau,AlphaSigmaAlpha,AlphaEpsilonPi,SigmaDeltaTau,TriDelta,katespadeny,katespadenewyork,charmingcharlie,verabradley,lillypulitzer"
    tags.split(',').each do |tag_name|
      self.perform_async tag_name
    end
  end
end