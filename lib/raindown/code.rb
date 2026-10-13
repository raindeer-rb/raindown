# frozen_string_literal: true

require 'commonmarker'

module Raindown
  # Finds code in Markdown the way Commonmarker reads it: code spans and fenced, indented or quoted code blocks.
  module Code
    module_function

    # Byte ranges of code in the Markdown, from Commonmarker's line and column positions.
    def ranges(markdown)
      line_offsets = markdown.each_line.reduce([0]) { |offsets, line| offsets << (offsets.last + line.bytesize) }
      ranges = []

      Commonmarker.parse(markdown, options: MARKDOWN_OPTIONS).walk do |node|
        ranges << range(node.source_position, line_offsets) if %i[code code_block].include?(node.type)
      end

      ranges
    end

    def range(position, line_offsets)
      start = line_offsets[position[:start_line] - 1] + position[:start_column] - 1
      # A block that ends with its last line ends at column 0 of the line after.
      finish = line_offsets[position[:end_line] - 1] + position[:end_column]
      start...finish
    end

    # Swaps braces in code for the placeholders that render as braces, so Antlers leaves them alone.
    def hide_braces(markdown)
      ranges(markdown).reverse.each_with_object(markdown.b) do |range, bytes|
        bytes[range] = bytes[range].force_encoding('UTF-8').gsub(/[{}]/, CODE_BRACES).b
      end.force_encoding('UTF-8')
    end
  end
end
