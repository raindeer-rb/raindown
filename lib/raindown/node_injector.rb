# frozen_string_literal: true

require_relative 'bare_directives'
require_relative 'front_matter'
require_relative 'node_blocks'

module Raindown
  # Writes each node block's Markdown below its directive, replacing what it wrote before.
  class NodeInjector
    class BlankLine < StandardError; end

    # Rewriter interface. Content without a node block is returned unchanged.
    def self.rewrite(content:, path: nil, bare: false, **)
      new(content:, path:, bare:).call
    end

    def initialize(content:, path: nil, bare: false)
      @content = content
      @bare = BareDirectives.enabled?(path:, bare:)
    end

    def call
      lines = @content.lines
      blocks = NodeBlocks.find(lines, front_matter: FrontMatter.parse(@content).first, bare: @bare)
      return @content if blocks.empty?

      blocks.reverse_each { |block| lines[block[:open]..block[:last]] = block_lines(lines, block) }
      lines.join
    end

    private

    def block_lines(lines, block)
      markdown = block[:node].markdown.to_s.chomp
      written = markdown.empty? ? [] : "#{markdown}\n".lines
      return [line(lines[block[:open]]), *bare(written, block)] unless block[:close]

      delimited(lines, block, written)
    end

    # The directive, what the node wrote and the end tag, each separated by a blank line.
    def delimited(lines, block, written)
      result = [line(lines[block[:open]])]
      result.push("\n", *written) unless written.empty?
      result.push("\n", line(lines[block[:close]]))
    end

    # A bare block ends at the next blank line, so what it writes can't have one.
    def bare(written, block)
      return written unless written.any? { |line| line.strip.empty? }

      name = block[:node].class.name
      raise BlankLine, "#{name} writes blank lines, so it needs <{ #{name}: }> and <{ :#{name} }> around it"
    end

    def line(line)
      line.end_with?("\n") ? line : "#{line}\n"
    end
  end
end
