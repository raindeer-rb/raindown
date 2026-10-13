# frozen_string_literal: true

require_relative 'code_blocks'

module Raindown
  # Raindown files (.rd/.raindown) can write a directive like <{ :toc }> as a bare :toc on its own line.
  # Markdown files opt in with the --bare flag.
  module BareDirectives
    EXTENSIONS = %w[.rd .raindown].freeze
    # The directives that take no arguments. :list closes a <{ list: ... }> block.
    KEYWORDS = %w[:toc :list].freeze
    # The block directives that take arguments, and the CodeBlocks method that finds the code blocks they hold.
    BLOCK_KEYWORDS = { 'endpoint:' => :endpoint }.freeze
    # Four spaces of indent would make the line a Markdown code block.
    LINE = /\A( {0,3})(#{KEYWORDS.join('|')}|(#{BLOCK_KEYWORDS.keys.join('|')})(?:[ \t]+\S.*?)?)[ \t]*$/

    module_function

    def enabled?(path: nil, bare: false)
      bare || file?(path)
    end

    def file?(path)
      return false if path.nil?

      EXTENSIONS.include?(File.extname(path).downcase)
    end

    # Wrap each bare directive in Antlers delimiters, leaving fenced code as-is.
    def expand(content)
      lines = content.lines
      index = 0

      while index < lines.length
        block = CodeBlocks.at(lines, index)
        index = (block ? block[:close] : expand_line(lines, index)) + 1
      end

      lines.join
    end

    # The directive in Antlers delimiters, or nil when the line isn't a bare directive.
    def wrap(line)
      line.sub(LINE) { "#{::Regexp.last_match(1)}<{ #{::Regexp.last_match(2)} }>" } if line.match?(LINE)
    end

    # Returns the index of the last line it handled.
    def expand_line(lines, index)
      match = lines[index].match(LINE)
      return index unless match

      lines[index] = wrap(lines[index])
      return index unless match[3]

      close_block(lines, index, indent: match[1], keyword: match[3])
    end

    # Bare block directives have no end tag, so it goes after the code blocks they hold.
    def close_block(lines, index, indent:, keyword:)
      last = CodeBlocks.public_send(BLOCK_KEYWORDS[keyword], lines, index + 1).last&.fetch(:close) || index
      lines[last] = "#{lines[last]}\n" unless lines[last].end_with?("\n")
      lines.insert(last + 1, "#{indent}<{ :#{keyword.delete_suffix(':')} }>\n")

      last + 1
    end
  end
end
