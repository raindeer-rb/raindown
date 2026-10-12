# frozen_string_literal: true

require 'antlers/api'

module Raindown
  # Holds an endpoint's curl snippet and response, which render as the code blocks they are.
  class EndpointNode < Antlers::BranchNode
    DEF_KEY = :endpoint_def
    END_KEY = :endpoint_end

    class << self
      def match?(segment:)
        segment[DEF_KEY]
      end

      def build(**)
        new(name: :endpoint)
      end
    end
  end
end
