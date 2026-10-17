# frozen_string_literal: true

require 'antlers/api'
require_relative '../raindown/directives'
require_relative '../raindown/fragments'

module Raindown
  # Holds an endpoint's curl snippet and response, which render as the code blocks they are,
  # between Directives markers for its directive and end tag, kept as a fragment.
  class EndpointNode < Antlers::BranchNode
    DEF_KEY = :endpoint_def
    END_KEY = :endpoint_end

    def initialize(name:, directive: 'endpoint:', **)
      super(name:, **)

      @directive = directive
    end

    def render(**)
      html = Raindown.commonmark(super)
      Fragments.add("#{Directives.marker(@directive)}\n#{html}#{Directives.marker(':endpoint')}")
    end

    class << self
      def match?(segment:)
        segment[DEF_KEY]
      end

      def build(segment:, **)
        new(name: :endpoint, directive: segment[DEF_KEY].map { |keyword, value| [keyword, value].compact.join(' ') }.join(' '))
      end
    end
  end
end
