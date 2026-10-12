# frozen_string_literal: true

require 'plugs'

module Raindown
  class Elements
    include Plugs

    plug(:toc) do
      plug(:lexeme) do
        require_relative 'lexemes/toc_lexeme'
        TOCLexeme
      end

      plug(:node) do
        require_relative 'nodes/toc_node'
        TOCNode
      end
    end

    plug(:endpoint) do
      plug(:lexeme) do
        require_relative 'lexemes/endpoint_lexeme'
        EndpointLexeme
      end

      plug(:node) do
        require_relative 'nodes/endpoint_node'
        EndpointNode
      end
    end

    plug(:list) do
      plug(:lexeme) do
        require_relative 'lexemes/list_lexeme'
        ListLexeme
      end

      plug(:node) do
        require_relative 'nodes/list_node'
        ListNode
      end
    end
  end
end
