# frozen_string_literal: true

require 'commonmarker'

module Raindown
  # A Markdown file's structure, read from its source so each part has the line it's on, for tools like an editor.
  # Headings that a directive writes back below it are in the source too, while ones a node only renders as HTML aren't.
  class Document
    Heading = Data.define(:level, :text, :line)

    # Inline nodes whose text a reader sees, like code spans, as opposed to inline HTML tags.
    TEXT_NODES = %i[text code].freeze
    BREAK_NODES = %i[softbreak linebreak].freeze

    def self.parse(markdown)
      new(markdown:)
    end

    def initialize(markdown:)
      @root = Commonmarker.parse(markdown, options: MARKDOWN_OPTIONS)
    end

    # The headings in the order they appear, with their source text, like "Notes for {name}" before it's rendered.
    def headings
      @headings ||= nodes(:heading).map do |node|
        Heading.new(level: node.header_level, text: text(node), line: node.source_position[:start_line])
      end
    end

    private

    def nodes(type)
      [].tap { |nodes| @root.walk { |node| nodes << node if node.type == type } }
    end

    def text(heading)
      parts = []
      heading.walk do |node|
        parts << node.string_content if TEXT_NODES.include?(node.type)
        parts << ' ' if BREAK_NODES.include?(node.type)
      end
      parts.join.strip
    end
  end
end
