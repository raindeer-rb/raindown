# frozen_string_literal: true

require_relative 'code_blocks'
require_relative 'front_matter'
require_relative 'nodes'

module Raindown
  # Finds node blocks in a file's lines: a node's directive and the Markdown it wrote below it.
  # With delimiters the block ends with the node's end tag, and without them at the next blank line:
  #   <{ Changelog: limit=3 }>          Changelog: limit=3
  #                                     - **1.2.0** Bare directives
  #   - **1.2.0** Bare directives
  #
  #   <{ :Changelog }>
  # A name only starts a block when it's a loaded node, so other text like "Note:" is left alone.
  module NodeBlocks
    class MissingEndTag < StandardError; end

    NAME = '[A-Z]\w*(?:::[A-Z]\w*)*'
    OPEN = /\A( {0,3})<\{\s*(#{NAME}):(?:\s+(.*?))?\s*\}>[ \t]*$/
    BARE_OPEN = /\A( {0,3})(#{NAME}):(?:[ \t]+(.*?))?[ \t]*$/
    # A prop is name=value, where the value is quoted text, a number, true, false or a front matter key like author.name.
    PROP = /(\w+)=("[^"]*"|'[^']*'|\S+)/

    module_function

    # Each block outside code and front matter as { open:, close:, last:, node: }, where close is nil for a bare block.
    def find(lines, front_matter: {}, bare: false)
      blocks = []
      index = FrontMatter.line_count(lines)

      while index < lines.length
        if (code = CodeBlocks.at(lines, index))
          index = code[:close]
        elsif (block = block_at(lines, index, front_matter:, bare:))
          blocks << block
          index = block[:last]
        end

        index += 1
      end

      blocks
    end

    # Swaps each block for its node's HTML, through a placeholder, or for its Markdown when it has no HTML of its own.
    def to_rendered(markdown, bare: false)
      lines = markdown.lines
      find(lines, front_matter: FrontMatter.parse(markdown).first, bare:).reverse_each do |block|
        node = block[:node]
        lines[block[:open]..block[:last]] = Nodes.html?(node) ? ["#{Nodes.placeholder(node)}\n"] : "#{node.markdown.to_s.chomp}\n".lines
      end
      lines.join
    end

    def block_at(lines, index, front_matter:, bare:)
      match = lines[index].match(OPEN) || (bare && lines[index].match(BARE_OPEN))
      return unless match && (klass = Nodes.node_class(match[2]))

      node = Nodes.instance(klass, props(match[3].to_s, front_matter))
      return bare_block(lines, index, node) unless lines[index].match?(OPEN)

      close = end_tag(lines, index, match[2])
      { open: index, close:, last: close, node: }
    end

    # A bare block holds the lines straight below it, up to the next blank line, with fenced code kept whole.
    def bare_block(lines, open, node)
      last = open
      last = CodeBlocks.at(lines, last + 1)&.fetch(:close) || (last + 1) while lines[last + 1] && !lines[last + 1].strip.empty?

      { open:, close: nil, last:, node: }
    end

    def end_tag(lines, open, name)
      tag = /\A {0,3}<\{\s*:#{Regexp.escape(name)}\s*\}>[ \t]*$/
      close = (open + 1...lines.length).find { |index| lines[index].match?(tag) }
      raise MissingEndTag, "<{ #{name}: }> on line #{open + 1} needs <{ :#{name} }>" unless close

      close
    end

    def props(text, front_matter)
      text.scan(PROP).to_h { |name, value| [name.to_sym, value(value, front_matter)] }
    end

    def value(value, front_matter)
      case value
      when /\A(["']).*\1\z/ then value[1..-2]
      when /\A-?\d+\z/ then value.to_i
      when /\A-?\d+\.\d+\z/ then value.to_f
      when 'true', 'false' then value == 'true'
      else value.split('.').reduce(front_matter) { |data, key| data.is_a?(Hash) ? data[key.to_sym] : nil }
      end
    end
  end
end
