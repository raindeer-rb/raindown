# frozen_string_literal: true

require 'antlers/api'

module Raindown
  # The curl snippet and its response are plain code blocks, so the directive itself renders nothing.
  class EndpointNode < Antlers::LeafNode
    def render(**)
      ''
    end

    class << self
      def match?(segment:)
        segment[:endpoint]
      end

      def build(**)
        new(name: :endpoint)
      end
    end
  end
end
