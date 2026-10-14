# frozen_string_literal: true

require 'strscan'
require_relative '../raindown'
require_relative 'bare_directives'

module Raindown
  class TOCInjector
    START_MARKER = '<!-- raindown:toc -->'
    END_MARKER = '<!-- /raindown:toc -->'
    DIRECTIVE = '<{ :toc }>'
    # Bare directives also accept :toc on its own line.
    BARE_DIRECTIVE = Regexp.union(DIRECTIVE, /^ {0,3}:toc[ \t]*$/)

    # Rewriter interface. Content without a TOC directive is returned unchanged.
    def self.rewrite(content:, path: nil, bare: false, **)
      new(content:, path:, bare:).call
    end

    def initialize(content:, path: nil, bare: false)
      @content = content
      @bare = BareDirectives.enabled?(path:, bare:)
      @directive = @bare ? BARE_DIRECTIVE : Regexp.union(DIRECTIVE)
    end

    def call
      block = "#{START_MARKER}\n#{markdown_list}\n#{END_MARKER}"

      if @content.include?(START_MARKER) && @content.include?(END_MARKER)
        @content.sub(/#{Regexp.escape(START_MARKER)}.*?#{Regexp.escape(END_MARKER)}/m, block)
      elsif (finish = directive_end)
        "#{@content.byteslice(0, finish)}\n\n#{block}#{@content.byteslice(finish..)}"
      else
        @content
      end
    end

    private

    # Where the first directive outside code ends, as a byte offset.
    def directive_end
      return unless @content.match?(@directive)

      # Code ranges are in document order, so the one a directive could be in is found by binary search.
      code = Code.ranges(@content)
      scanner = StringScanner.new(@content)

      while scanner.skip_until(@directive)
        start = scanner.pos - scanner.matched_size
        return scanner.pos unless code.bsearch { |range| range.end > start }&.cover?(start)
      end

      nil
    end

    def markdown_list
      headings = Raindown.headings(markdown: @content, bare: @bare)
      return '' if headings.empty?

      min_level = headings.map { |heading| heading[:level] }.min

      headings.map do |heading|
        indent = '  ' * (heading[:level] - min_level)
        "#{indent}- [#{heading[:text]}](##{heading[:id]})"
      end.join("\n")
    end
  end
end
