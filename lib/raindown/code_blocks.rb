# frozen_string_literal: true

module Raindown
  # Finds fenced code blocks in a file's lines.
  module CodeBlocks
    FENCE = /\A {0,3}(`{3,}|~{3,})/

    module_function

    # The block opening at index, closed by a fence of the same character that's at least as long.
    def at(lines, index)
      fence = lines[index]&.[](FENCE, 1)
      return unless fence

      close = (index + 1...lines.length).find { |i| lines[i].match?(/\A {0,3}#{fence[0]}{#{fence.length},}[ \t]*$/) }
      { open: index, close:, body: lines[index + 1...close].join } if close
    end

    # Up to limit blocks from index on, with only blank lines before and between them.
    def following(lines, index, limit:)
      blocks = []

      while blocks.length < limit && (block = at(lines, skip_blank_lines(lines, index)))
        blocks << block
        index = block[:close] + 1
      end

      blocks
    end

    def skip_blank_lines(lines, index)
      index += 1 while lines[index]&.strip&.empty?
      index
    end
  end
end
