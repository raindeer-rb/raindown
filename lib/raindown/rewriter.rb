# frozen_string_literal: true

require_relative 'node_injector'
require_relative 'endpoint/endpoint_runner'
require_relative 'table_formatter'

module Raindown
  # Rewrites the generated parts of a Markdown file in place before it's rendered:
  # node output, like the TOC, endpoint responses and table alignment.
  # Each rewriter responds to rewrite(content:, path:, bare:, execute:, metadata:) and returns the new content.
  module Rewriter
    REWRITERS = [NodeInjector, EndpointRunner, TableFormatter].freeze

    module_function

    def rewrite(content:, path:, bare: false, execute: false, metadata: NoMetadata)
      REWRITERS.reduce(content) do |rewritten, rewriter|
        rewriter.rewrite(content: rewritten, path:, bare:, execute:, metadata:)
      end
    end

    # Returns true when the file changed.
    def update(path:, bare: false, execute: false, metadata: NoMetadata)
      content = File.read(path, encoding: Encoding::UTF_8)
      rewritten = rewrite(content:, path:, bare:, execute:, metadata:)
      return false if rewritten == content

      File.write(path, rewritten)
      true
    end
  end
end
