# frozen_string_literal: true

require 'antlers/api'

module Raindown
  module EndpointLexeme
    include Antlers::Lexeme

    module_function

    KEYWORDS = ['endpoint:', ':endpoint'].freeze

    def match?(keywords:, **)
      KEYWORDS.include?(keywords.keys.first)
    end

    def lexeme(keywords:, **)
      return { endpoint_def: keywords } if keywords.key?('endpoint:')

      { endpoint_end: 'level_1' }
    end
  end
end
