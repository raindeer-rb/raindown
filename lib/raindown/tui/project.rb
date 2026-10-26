# frozen_string_literal: true

require_relative '../actions'
require_relative '../bare_directives'
require_relative '../chart/chart'
require_relative '../document'
require_relative '../front_matter'
require_relative '../node_blocks'
require_relative '../nodes'
require_relative '../pages'
require_relative '../projects'

module Raindown
  module TUI
    # What the terminal UI asks of a project, answered in the project's Worker with its own nodes loaded,
    # so two projects' nodes of the same name stay apart. Answers are plain data, which a Worker sends back through a pipe.
    class Project
      # A chart drawn from its data, under the heading above its directive.
      Card = Data.define(:path, :line, :heading, :directive, :lines)
      Outline = Data.define(:lines, :headings, :directives)

      attr_reader :root

      # The projects inside this one have workers of their own, so their files are left out.
      def initialize(root:)
        @root = root
        @load_errors = []
        @file_errors = []
        Nodes.load(File.join(root, Nodes::FOLDER))
      rescue StandardError, ScriptError => e
        @load_errors << "#{File.basename(root)}/#{Nodes::FOLDER}: #{e.message}"
      end

      # A file's lines, headings and directives.
      def outline(path)
        document = Document.read(path)
        Outline.new(lines: File.readlines(path, chomp: true), headings: document.headings, directives: document.directives)
      end

      # Every chart in the project's files, drawn from its data, and the files that couldn't be read.
      # The charts are found again when asked, and otherwise drawn again, so they follow changes to their data.
      def charts(find: false)
        if find || @charts.nil?
          @file_errors = []
          @charts = Projects.files(root).flat_map { |path| charts_in(path) }
        end

        pages = {}
        cards = @charts.map do |chart|
          chart.merge(lines: lines(chart, pages[File.dirname(chart[:path])] ||= Pages.for(chart[:path])))
        end
        { cards: cards.map { Card.new(**it.except(:node)) }, errors: @load_errors + @file_errors }
      end

      def write_back(path)
        Actions.write_back(path)
      end

      # Runs the endpoint on the line, replacing its response.
      def execute(path, line)
        directive = Document.read(path).directives.find { it.line == line && it.endpoint? }
        raise Actions::NotAnEndpoint, "There's no endpoint on line #{line}" unless directive

        Actions.execute(path, directive)
      end

      private

      def charts_in(path)
        content = File.read(path, encoding: Encoding::UTF_8)
        bare = BareDirectives.enabled?(path:, content:)
        lines = content.lines
        headings = Document.parse(content, bare:).headings

        NodeBlocks.find(lines, front_matter: FrontMatter.parse(content).first, bare:)
                  .select { |block| block[:node].is_a?(Raindown::Chart) }
                  .map { |block| chart(block, path:, lines:, headings:) }
      rescue StandardError => e
        @file_errors << "#{path.delete_prefix(File.join(root, ''))}: #{e.message}"
        []
      end

      def chart(block, path:, lines:, headings:)
        line = block[:open] + 1
        directive = lines[block[:open]].strip.delete_prefix('<{').delete_suffix('}>').strip

        { path:, line:, heading: headings.select { it.line < line }.last&.text, directive:, node: block[:node] }
      end

      # Draws the chart as its Markdown would be written back, with the files its project lists.
      def lines(chart, metadata)
        node = chart[:node]
        points = node.points(metadata:)
        points.empty? ? ['No data'] : node.draw(points).map(&:rstrip)
      rescue StandardError => e
        ["Can't chart: #{e.message}"]
      end
    end
  end
end
