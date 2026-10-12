# frozen_string_literal: true

require_relative 'front_matter'

module Raindown
  # Raindown files (.rd/.raindown) can write a directive like <{ :toc }> as a bare :toc on its own line.
  # Markdown files opt in with the --bare flag or "bare: true" in their front matter.
  module BareDirectives
    EXTENSIONS = %w[.rd .raindown].freeze
    # The directives that take no arguments. :list closes a <{ list: ... }> block.
    KEYWORDS = %w[:toc :list].freeze
    # Four spaces of indent would make the line a Markdown code block.
    LINE = /\A( {0,3})(#{KEYWORDS.join('|')})[ \t]*$/
    FENCE = /\A\s*(```|~~~)/

    module_function

    def enabled?(content:, path: nil, bare: false)
      bare || file?(path) || front_matter?(content)
    end

    def file?(path)
      return false if path.nil?

      EXTENSIONS.include?(File.extname(path).downcase)
    end

    def front_matter?(content)
      FrontMatter.parse(content).first[:bare] == true
    end

    # Wrap each bare directive in Antlers delimiters, leaving fenced code as-is.
    def expand(content)
      in_fence = false

      content.lines.map do |line|
        in_fence = !in_fence if line.match?(FENCE)
        next line if in_fence

        line.sub(LINE) { "#{::Regexp.last_match(1)}<{ #{::Regexp.last_match(2)} }>" }
      end.join
    end
  end
end
