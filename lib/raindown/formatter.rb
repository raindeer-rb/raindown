# frozen_string_literal: true

require_relative 'toc_injector'
require_relative 'table_aligner'

module Raindown
  # Tidies a Markdown file in place before it's rendered.
  # Each formatter responds to format(content:, path:) and returns the new content.
  module Formatter
    FORMATTERS = [TOCInjector, TableAligner].freeze

    module_function

    def format(content:, path:)
      FORMATTERS.reduce(content) { |formatted, formatter| formatter.format(content: formatted, path:) }
    end

    # Returns true when the file changed.
    def update(path:)
      content = File.read(path)
      formatted = format(content:, path:)
      return false if formatted == content

      File.write(path, formatted)
      true
    end
  end
end
