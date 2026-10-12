# frozen_string_literal: true

require_relative 'toc_injector'
require_relative 'table_aligner'

module Raindown
  # Tidies a Markdown file in place before it's rendered.
  # Each formatter responds to format(content:, path:, bare:) and returns the new content.
  module Formatter
    FORMATTERS = [TOCInjector, TableAligner].freeze

    module_function

    def format(content:, path:, bare: false)
      FORMATTERS.reduce(content) { |formatted, formatter| formatter.format(content: formatted, path:, bare:) }
    end

    # Returns true when the file changed.
    def update(path:, bare: false)
      content = File.read(path)
      formatted = format(content:, path:, bare:)
      return false if formatted == content

      File.write(path, formatted)
      true
    end
  end
end
