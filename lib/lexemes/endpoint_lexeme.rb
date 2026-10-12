# frozen_string_literal: true

require 'antlers/api'

module Raindown
  module EndpointLexeme
    include Antlers::Lexeme

    module_function

    KEYWORDS = ['endpoint:'].freeze

    def match?(keywords:, **)
      keywords.key?('endpoint:')
    end

    def lexeme(keywords:, **)
      { endpoint: keywords }
    end
  end
end
