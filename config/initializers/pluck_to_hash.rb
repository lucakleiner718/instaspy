require 'mongoid'

module PluckToHash
  module Mongoid
    module CriteriaMethods
      def pluck_to_hash *keys
        pluck(*keys).map{|row| Hash[Array(keys).zip(Array(row))]}
      end
    end

    ::Mongoid::Criteria.send(:include, CriteriaMethods)
  end
end