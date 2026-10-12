# frozen_string_literal: true

require_relative '../raindown'
require_relative 'bare_directives'

module Raindown
  class TOCInjector
    START_MARKER = '<!-- raindown:toc -->'
    END_MARKER = '<!-- /raindown:toc -->'
    DIRECTIVE = '<{ :toc }>'
    # Bare directives also accept :toc on its own line.
    BARE_DIRECTIVE = Regexp.union(DIRECTIVE, /^ {0,3}:toc[ \t]*$/)

    # Formatter interface. Content without a TOC directive is returned unchanged.
    def self.format(content:, path: nil, bare: false, **)
      new(content:, path:, bare:).call
    end

    def initialize(content:, path: nil, bare: false)
      @content = content
      @directive = BareDirectives.enabled?(content:, path:, bare:) ? BARE_DIRECTIVE : DIRECTIVE
    end

    def call
      block = "#{START_MARKER}\n#{markdown_list}\n#{END_MARKER}"

      if @content.include?(START_MARKER) && @content.include?(END_MARKER)
        @content.sub(/#{Regexp.escape(START_MARKER)}.*?#{Regexp.escape(END_MARKER)}/m, block)
      elsif @content.match?(@directive)
        @content.sub(@directive) { |directive| "#{directive}\n\n#{block}" }
      else
        @content
      end
    end

    private

    def markdown_list
      headings = Raindown.headings(markdown: @content)
      return '' if headings.empty?

      min_level = headings.map { |heading| heading[:level] }.min

      headings.map do |heading|
        indent = '  ' * (heading[:level] - min_level)
        "#{indent}- [#{heading[:text]}](##{heading[:id]})"
      end.join("\n")
    end
  end
end
