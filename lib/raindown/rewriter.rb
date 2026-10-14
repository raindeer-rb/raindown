# frozen_string_literal: true

require_relative 'toc_injector'
require_relative 'endpoint/endpoint_runner'
require_relative 'table_formatter'

module Raindown
  # Rewrites the generated parts of a Markdown file in place before it's rendered:
  # the TOC, endpoint responses and table alignment.
  # Each rewriter responds to rewrite(content:, path:, bare:, execute:) and returns the new content.
  module Rewriter
    REWRITERS = [TOCInjector, EndpointRunner, TableFormatter].freeze

    module_function

    def rewrite(content:, path:, bare: false, execute: false)
      REWRITERS.reduce(content) { |rewritten, rewriter| rewriter.rewrite(content: rewritten, path:, bare:, execute:) }
    end

    # Returns true when the file changed.
    def update(path:, bare: false, execute: false)
      content = File.read(path)
      rewritten = rewrite(content:, path:, bare:, execute:)
      return false if rewritten == content

      File.write(path, rewritten)
      true
    end
  end
end
