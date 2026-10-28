# frozen_string_literal: true

require 'lowkey'

require_relative 'code_blocks'
require_relative 'directives'
require_relative 'front_matter'
require_relative 'nodes'
require_relative 'variables'

module Raindown
  # Finds node blocks in a file's lines: a node's directive and the Markdown it wrote below it.
  # With delimiters the block ends with the node's end tag, and without them at the next blank line:
  #   <{ Changelog: limit=3 }>          Changelog: limit=3
  #                                     - **1.2.0** Bare directives
  #   - **1.2.0** Bare directives
  #
  #   <{ :Changelog }>
  # A self-closing <{ :Changelog }> or bare :Changelog that doesn't end a block renders the node without writing it.
  # toc: and files: are Raindown's own nodes. A name only starts a block when it's a loaded node,
  # so other text like "Note:" is left alone.
  module NodeBlocks
    class MissingEndTag < StandardError; end

    NAME = "(?:#{Nodes::BUILT_INS.keys.join('|')}|[A-Z]\\w*(?:::[A-Z]\\w*)*)".freeze
    OPEN = /\A( {0,3})<\{\s*(#{NAME}):(?:\s+(.*?))?\s*\}>[ \t]*$/
    BARE_OPEN = /\A( {0,3})(#{NAME}):(?:[ \t]+(.*?))?[ \t]*$/
    SELF_CLOSING = /\A( {0,3})<\{\s*:(#{NAME})(?:\s+(.*?))?\s*\}>[ \t]*$/
    BARE_SELF_CLOSING = /\A( {0,3}):(#{NAME})(?:[ \t]+(.*?))?[ \t]*$/
    # A prop is name=value or name: value, where the value is quoted text, a number, true, false
    # or a variable like author.name.
    PROP = /(\w+)(?:=|:[ \t]+)("[^"]*"|'[^']*'|\S+)/
    # A value before the props is the node's argument.
    ARG = /\A("[^"]*"|'[^']*'|[^\s"']\S*)(?:\s+|\z)/

    module_function

    # Each block outside code and front matter as { open:, close:, last:, node: }, where close is nil for a bare block.
    # A self-closing node is a block of one line with self_closing: true.
    def find(lines, front_matter: {}, bare: false)
      variables = Variables.new(front_matter)

      spans(lines, bare:).map do |span|
        span.except(:name, :class, :args).merge(node: Nodes.instance(span[:class], *args(span[:args], variables)))
      end
    end

    # Each block like find's, with the node's name, class and props text in place of the node,
    # so a block can be found without making its node, like for a document's outline.
    def spans(lines, bare: false)
      spans = []
      index = FrontMatter.line_count(lines)

      while index < lines.length
        if (code = CodeBlocks.at(lines, index))
          index = code[:close]
        elsif (span = span_at(lines, index, bare:))
          spans << span
          index = span[:last]
        end

        index += 1
      end

      spans
    end

    # Swaps each block for its node's HTML, through a placeholder, or for its Markdown when it has no HTML of its own.
    # The directive and end tag become Directives markers, which also keep the node's output from joining
    # the Markdown around it, like two lists becoming one.
    def to_rendered(markdown, metadata: NoMetadata, bare: false)
      lines = markdown.lines
      find(lines, front_matter: FrontMatter.parse(markdown).first, bare:).reverse_each do |block|
        lines[block[:open]..block[:last]] = rendered_lines(lines, block, markdown:, metadata:, bare:)
      end
      lines.join
    end

    def rendered_lines(lines, block, markdown:, metadata:, bare:)
      output = node_markdown(block[:node], markdown:, metadata:, bare:).chomp
      close = marker(lines[block[:close]]) if block[:close]

      [marker(lines[block[:open]]), *("#{output}\n".lines unless output.empty?), *close]
    end

    def node_markdown(node, markdown:, metadata:, bare:)
      return Nodes.placeholder(node) if Nodes.html?(node)

      Nodes.call(node, :replace, document: markdown, metadata:, bare:).to_s
    end

    def marker(line)
      "#{Directives.marker(line)}\n"
    end

    def span_at(lines, index, bare:)
      found, pattern = directive(lines[index], bare:)
      return unless found && (klass = Nodes.node_class(found[2]))

      span = { name: found[2], class: klass, args: found[3].to_s }
      case pattern
      when :open then end_tag(lines, index, found[2]).then { |close| { open: index, close:, last: close, **span } }
      when :bare_open then { **bare_block(lines, index), **span }
      else { open: index, close: nil, last: index, self_closing: true, **span }
      end
    end

    # The directive on the line and which kind it is, or nil.
    def directive(line, bare:)
      patterns = { open: OPEN, self_closing: SELF_CLOSING }
      patterns.merge!(bare_open: BARE_OPEN, bare_self_closing: BARE_SELF_CLOSING) if bare

      patterns.each do |pattern, regexp|
        match = line.match(regexp)
        return [match, pattern] if match
      end

      nil
    end

    # A bare block holds the lines straight below it, up to the next blank line, with fenced code kept whole.
    def bare_block(lines, open)
      last = open
      last = CodeBlocks.at(lines, last + 1)&.fetch(:close) || (last + 1) while lines[last + 1] && !lines[last + 1].strip.empty?

      { open:, close: nil, last: }
    end

    def end_tag(lines, open, name)
      tag = /\A {0,3}<\{\s*:#{Regexp.escape(name)}\s*\}>[ \t]*$/
      close = (open + 1...lines.length).find { |index| lines[index].match?(tag) }
      raise MissingEndTag, "<{ #{name}: }> on line #{open + 1} needs <{ :#{name} }>" unless close

      close
    end

    # The props, after a value that's the node's argument when it comes first, like 'data.csv' in chart: 'data.csv'.
    def args(text, variables)
      arg = text.match(ARG) unless text.match?(/\A#{PROP}/)
      return [props(text, variables)] unless arg

      [props(arg.post_match, variables), [value(arg[1], variables)]]
    end

    def props(text, variables)
      text.scan(PROP).to_h { |name, value| [name.to_sym, value(value, variables)] }
    end

    # A value, like 'text', 3, true, nil or :draft, or else a variable, like author.name.
    def value(value, variables)
      Lowkey::ValueParser.parse(value) do
        next value[1..-2] if value.match?(/\A(["']).*\1\z/)

        Variables.value(variables, value)
      end
    end
  end
end
