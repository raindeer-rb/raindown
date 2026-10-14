# frozen_string_literal: true

require_relative 'code_blocks'
require_relative 'front_matter'

module Raindown
  # Finds toc: blocks in a file's lines: the directive, the Markdown TOC injected below it, and an optional end tag.
  #   <{ toc: }>
  #
  #   - [Title](#title)
  #
  #   <{ :toc }>
  # The end tag is optional, and only ends the block when it's the next line after the TOC that isn't blank.
  # Anywhere else <{ :toc }> is its own directive. Both render a TOC in the HTML.
  module TOCBlocks
    OPEN = /\A {0,3}<\{\s*toc:\s*\}>[ \t]*$/
    CLOSE = /\A {0,3}<\{\s*:toc\s*\}>[ \t]*$/
    # Bare directives also accept toc: and :toc on their own lines.
    BARE_OPEN = /\A {0,3}toc:[ \t]*$/
    BARE_CLOSE = /\A {0,3}:toc[ \t]*$/
    ENTRY = /\A[ \t]*- \[.*\]\(#.*\)[ \t]*$/

    module_function

    # Each block outside code and front matter as { open:, close:, last: }, where close is nil without an end tag.
    def find(lines, bare: false)
      blocks = []
      index = front_matter_length(lines)

      while index < lines.length
        if (code = CodeBlocks.at(lines, index))
          index = code[:close]
        elsif open?(lines[index], bare:)
          blocks << block(lines, index, bare:)
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

    # Front matter is YAML, where toc: could be a key.
    def front_matter_length(lines)
      lines.join.match(FrontMatter::PATTERN)&.then { |match| match[0].lines.length } || 0
    end

    def block(lines, open, bare:)
      last = open
      index = open + 1

      while index < lines.length && (lines[index].strip.empty? || lines[index].match?(ENTRY))
        last = index if lines[index].match?(ENTRY)
        index += 1
      end

      close = index if index < lines.length && close?(lines[index], bare:)
      { open:, close:, last: close || last }
    end

    def open?(line, bare:)
      line.match?(OPEN) || (bare && line.match?(BARE_OPEN))
    end

    def close?(line, bare:)
      line.match?(CLOSE) || (bare && line.match?(BARE_CLOSE))
    end
  end
end
