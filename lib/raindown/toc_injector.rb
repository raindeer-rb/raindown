# frozen_string_literal: true

require_relative '../raindown'
require_relative 'bare_directives'
require_relative 'toc_blocks'

module Raindown
  # Writes a Markdown TOC into each toc: block, replacing the one already there.
  class TOCInjector
    # Rewriter interface. Content without a toc: block is returned unchanged.
    def self.rewrite(content:, path: nil, bare: false, **)
      new(content:, path:, bare:).call
    end

    def initialize(content:, path: nil, bare: false)
      @content = content
      @bare = BareDirectives.enabled?(path:, bare:)
    end

    def call
      lines = @content.lines
      blocks = TOCBlocks.find(lines, bare: @bare)
      return @content if blocks.empty?

      list = markdown_list
      blocks.reverse_each { |block| lines[block[:open]..block[:last]] = block_lines(lines, block, list) }
      lines.join
    end

    private

    # The directive, the TOC and the end tag, each separated by a blank line.
    def block_lines(lines, block, list)
      result = [line(lines[block[:open]])]
      result.push("\n", *list) unless list.empty?
      result.push("\n", line(lines[block[:close]])) if block[:close]
      result.push("\n") if gap_after?(lines, block, list)
      result
    end

    # Without an end tag, a blank line after the TOC stops the text below from joining its last item.
    def gap_after?(lines, block, list)
      !block[:close] && !list.empty? && !lines[block[:last] + 1].to_s.strip.empty?
    end

    def line(line)
      line.end_with?("\n") ? line : "#{line}\n"
    end

    def markdown_list
      headings = Raindown.headings(markdown: @content, bare: @bare)
      return [] if headings.empty?

      min_level = headings.map { |heading| heading[:level] }.min

      headings.map do |heading|
        indent = '  ' * (heading[:level] - min_level)
        "#{indent}- [#{heading[:text]}](##{heading[:id]})\n"
      end
    end
  end
end
