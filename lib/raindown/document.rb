# frozen_string_literal: true

require 'commonmarker'

require_relative '../raindown'
require_relative 'bare_directives'
require_relative 'code_blocks'
require_relative 'endpoint/endpoint_runner'
require_relative 'front_matter'
require_relative 'node_blocks'

module Raindown
  # A Markdown file's structure, read from its source so each part has the line it's on, for tools like an editor.
  # Headings that a directive writes back below it are in the source too, while ones a node only renders as HTML aren't.
  # Lines count from 1, from the top of the file.
  class Document
    Heading = Data.define(:level, :text, :line)

    # A content directive: a node, like toc: or a project's Changelog:, or an endpoint.
    # It spans line to end_line, its end tag, or the last line of a bare block.
    # Body is the lines inside it, between it and its end tag, like an endpoint's request and response.
    # Output is the lines Raindown writes back, like a node's Markdown or an endpoint's response, and is nil
    # when nothing's written yet. A self-closing directive like <{ :toc }> only renders, so it never writes.
    Directive = Data.define(:name, :args, :line, :end_line, :body, :output, :writes) do
      def endpoint? = name == 'endpoint'
    end

    # Inline nodes whose text a reader sees, like code spans, as opposed to inline HTML tags.
    TEXT_NODES = %i[text code].freeze
    BREAK_NODES = %i[softbreak linebreak].freeze
    ENDPOINT_END_TAG = /\A {0,3}<\{\s*:endpoint\s*\}>[ \t]*$/
    END_TAG = /\A {0,3}<\{\s*:[\w:]+\s*\}>[ \t]*$/

    def self.parse(markdown, bare: false)
      new(markdown:, bare:)
    end

    # Raindown files read bare directives, as do Markdown files with "raindown: true" front matter.
    # A project's own nodes are only directives once they're loaded, like with Nodes.load(path), the same as when the file renders.
    def self.read(path)
      new(markdown: File.read(path, encoding: Encoding::UTF_8), bare: BareDirectives.file?(path))
    end

    def initialize(markdown:, bare: false)
      @markdown = markdown
      @lines = markdown.lines
      @bare = bare || BareDirectives.front_matter?(markdown)
    end

    # The headings in the order they appear, with their source text, like "Notes for {name}" before it's rendered.
    def headings
      @headings ||= nodes(:heading).map do |node|
        Heading.new(level: node.header_level, text: text(node), line: node.source_position[:start_line])
      end
    end

    # The content directives in the order they appear. Template directives like if: and for: aren't here,
    # since they only change what renders, and write nothing back.
    def directives
      @directives ||= (node_directives + endpoint_directives).sort_by(&:line)
    end

    # The headings and directives together, in the order they appear.
    def outline
      (headings + directives).sort_by(&:line)
    end

    private

    def root
      @root ||= Commonmarker.parse(@markdown, options: MARKDOWN_OPTIONS)
    end

    def nodes(type)
      [].tap { |nodes| root.walk { |node| nodes << node if node.type == type } }
    end

    def text(heading)
      parts = []
      heading.walk do |node|
        parts << node.string_content if TEXT_NODES.include?(node.type)
        parts << ' ' if BREAK_NODES.include?(node.type)
      end
      parts.join.strip
    end

    def node_directives
      NodeBlocks.spans(@lines, bare: @bare).map do |span|
        output = trimmed(span[:open] + 1, span[:close] ? span[:close] - 1 : span[:last])
        directive(span[:name], span[:args], span[:open]..span[:last], output:, writes: !span[:self_closing])
      end
    end

    def endpoint_directives
      directives = []
      index = FrontMatter.line_count(@lines)

      while index < @lines.length
        if (code = CodeBlocks.at(@lines, index))
          index = code[:close]
        elsif (args = endpoint_args(@lines[index]))
          directives << endpoint(index, args)
          index = directives.last.end_line - 1
        end

        index += 1
      end

      directives
    end

    def endpoint_args(line)
      line = BareDirectives.wrap(line) || line if @bare
      line[EndpointRunner::DIRECTIVE, 1]&.strip
    end

    # The response and the date it was fetched are the output, while the curl snippet above them is the author's.
    def endpoint(open, args)
      curl, response = CodeBlocks.endpoint(@lines, open + 1)
      output = response && (response[:open]..(fetched?(response[:close] + 1) ? response[:close] + 1 : response[:close]))
      last = output&.end || curl&.fetch(:close) || open
      # A bare endpoint, which isn't delimited, ends after its blocks.
      last = end_tag(after: last) || last if @lines[open].match?(EndpointRunner::DIRECTIVE)

      directive('endpoint', args, open..last, output:, writes: true)
    end

    def fetched?(index)
      @lines[index]&.match?(EndpointRunner::FETCHED)
    end

    # The end tag after the endpoint's blocks, with only blank lines between.
    def end_tag(after:)
      index = CodeBlocks.skip_blank_lines(@lines, after + 1)
      index if @lines[index]&.match?(ENDPOINT_END_TAG)
    end

    # Lines from first to last with the blank lines around them left out, or nil when there are none.
    def trimmed(first, last)
      first += 1 while first <= last && @lines[first].strip.empty?
      last -= 1 while last >= first && @lines[last].strip.empty?
      first..last if first <= last
    end

    # From a range of indexes to line numbers. The body is the lines after the directive, up to its end tag,
    # or to the end of a bare block, which has none.
    def directive(name, args, span, output:, writes:)
      end_tag = span.end > span.begin && @lines[span.end].match?(END_TAG)
      body = trimmed(span.begin + 1, end_tag ? span.end - 1 : span.end)

      Directive.new(name:, args:, line: span.begin + 1, end_line: span.end + 1, body: lines(body), output: lines(output),
                    writes:)
    end

    def lines(range)
      (range.begin + 1)..(range.end + 1) if range
    end
  end
end
