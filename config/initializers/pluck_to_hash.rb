require 'mongoid'

module PluckToHash
  module Mongoid
    module CriteriaMethods
      def pluck_to_hash *keys
        only(*keys).to_a.inject({}) {|obj, r| keys.each{|key| obj[key] = r[key]}; obj}
      end
    end

    ::Mongoid::Criteria.send(:include, CriteriaMethods)
  end
end