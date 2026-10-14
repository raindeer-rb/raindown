# frozen_string_literal: true

require_relative 'code_blocks'
require_relative 'front_matter'

module Raindown
  # Finds toc: blocks in a file's lines: the directive and the Markdown TOC injected below it.
  # With delimiters the block needs an end tag after the TOC, and without them it ends with the TOC:
  #   <{ toc: }>           toc:
  #
  #   - [Title](#title)    - [Title](#title)
  #
  #   <{ :toc }>
  # A <{ :toc }> or :toc anywhere else is its own directive. Both render a TOC in the HTML.
  module TOCBlocks
    class MissingEndTag < StandardError; end

    OPEN = /\A {0,3}<\{\s*toc:\s*\}>[ \t]*$/
    CLOSE = /\A {0,3}<\{\s*:toc\s*\}>[ \t]*$/
    BARE_OPEN = /\A {0,3}toc:[ \t]*$/
    ENTRY = /\A[ \t]*- \[.*\]\(#.*\)[ \t]*$/

    module_function

    # Each block outside code and front matter as { open:, close:, last: }, where close is nil for a bare block.
    def find(lines, bare: false)
      blocks = []
      index = FrontMatter.line_count(lines)

      while index < lines.length
        if (code = CodeBlocks.at(lines, index))
          index = code[:close]
        elsif lines[index].match?(OPEN) || (bare && lines[index].match?(BARE_OPEN))
          blocks << block(lines, index)
          index = blocks.last[:last]
        end

        index += 1
      end

      blocks
    end

    # Swaps each toc: block for <{ :toc }>, so the HTML gets a TOC in place of the Markdown one.
    def to_directives(markdown, bare: false)
      lines = markdown.lines
      find(lines, bare:).reverse_each { |block| lines[block[:open]..block[:last]] = ["<{ :toc }>\n"] }
      lines.join
    end

    def block(lines, open)
      last = open
      index = open + 1

      while index < lines.length && (lines[index].strip.empty? || lines[index].match?(ENTRY))
        last = index if lines[index].match?(ENTRY)
        index += 1
      end

      return { open:, close: nil, last: } unless lines[open].match?(OPEN)

      # The block can only hold its TOC, so the end tag has to come next.
      raise MissingEndTag, "<{ toc: }> on line #{open + 1} needs <{ :toc }> after its table of contents" \
        unless index < lines.length && lines[index].match?(CLOSE)

      { open:, close: index, last: index }
    end
  end
end
