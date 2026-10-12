# frozen_string_literal: true

require_relative '../raindown'

module Raindown
  class TOCInjector
    START_MARKER = '<!-- raindown:toc -->'
    END_MARKER = '<!-- /raindown:toc -->'
    DIRECTIVE = '<{ :toc }>'

    # Formatter interface. Content without a TOC directive is returned unchanged.
    def self.format(content:, **)
      new(content:).call
    end

    def initialize(content:)
      @content = content
    end

    def call
      block = "#{START_MARKER}\n#{markdown_list}\n#{END_MARKER}"

      if @content.include?(START_MARKER) && @content.include?(END_MARKER)
        @content.sub(/#{Regexp.escape(START_MARKER)}.*?#{Regexp.escape(END_MARKER)}/m, block)
      elsif @content.include?(DIRECTIVE)
        @content.sub(DIRECTIVE, "#{DIRECTIVE}\n\n#{block}")
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
