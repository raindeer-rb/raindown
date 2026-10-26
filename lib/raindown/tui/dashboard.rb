# frozen_string_literal: true

require_relative '../bare_directives'
require_relative '../chart/chart'
require_relative '../document'
require_relative '../front_matter'
require_relative '../node_blocks'
require_relative '../pages'
require_relative '../projects'

module Raindown
  module TUI
    # Every chart in a project's Markdown files, drawn from its data, as cards in a grid with a cursor.
    # A chart is a chart: directive, or a project's own node that's a Raindown::Chart, like "Sales < Raindown::Chart".
    # Charts are drawn again every few seconds, so they follow changes to their data, like a CSV file, without a save.
    # Handle returns the Navigator's next step: nil, or [:open, path, line] or [:edit, path, line] for a chart's directive.
    class Dashboard
      Chart = Data.define(:path, :line, :heading, :directive, :node)
      Card = Data.define(:chart, :lines)

      # Seconds between drawing the charts again.
      REDRAW = 2
      MOVES = %i[up down left right].freeze

      attr_reader :root, :charts, :errors, :cursor
      # The cards' indexes in each row, which the Layout sets as it draws them, so up and down move a row.
      attr_writer :rows

      def initialize(root:)
        @root = root
        @cursor = 0
        @offset = 0
        @rows = []
        load
      end

      # Finds the charts again, like when a file is saved or added.
      def load
        @errors = []
        @charts = Projects.files(root, nested: true).flat_map { |path| charts_in(path) }
        @cursor = @cursor.clamp(0, [@charts.length - 1, 0].max)
        draw
      end

      def cards
        draw if Process.clock_gettime(Process::CLOCK_MONOTONIC) - @drawn_at >= REDRAW
        @cards
      end

      def selected = @charts[@cursor]

      def first_in_row?
        @rows.empty? || @rows.any? { it.first == @cursor }
      end

      def handle(event)
        name, *args = event
        case name
        when *MOVES then move(name)
        when :select then select(*args.last(1))
        when :press then press(args[1], args[2])
        when :enter then open
        when :edit then (chart = selected) && [:edit, chart.path, chart.line]
        when :reload then load.then { nil }
        end
      end

      # The first row of cards to show, given each row's height, scrolled so the cursor's row is shown.
      def scroll(row_heights, height)
        row = row_of(@cursor)
        @offset = row if row < @offset
        @offset += 1 while @offset < row && row_heights[@offset..row].sum > height
        @offset = @offset.clamp(0, [row_heights.length - 1, 0].max)
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
        @errors << "#{path.delete_prefix(File.join(root, ''))}: #{e.message}"
        []
      end

      # The chart, under the heading above it.
      def chart(block, path:, lines:, headings:)
        line = block[:open] + 1
        directive = lines[block[:open]].strip.delete_prefix('<{').delete_suffix('}>').strip

        Chart.new(path:, line:, heading: headings.select { it.line < line }.last&.text, directive:, node: block[:node])
      end

      # Draws each chart as its Markdown would be written back, with the files its project lists.
      def draw
        pages = {}
        @cards = @charts.map do |chart|
          Card.new(chart:, lines: lines(chart, pages[File.dirname(chart.path)] ||= Pages.for(chart.path)))
        end
        @drawn_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def lines(chart, metadata)
        points = chart.node.points(metadata:)
        points.empty? ? ['No data'] : chart.node.draw(points).map(&:rstrip)
      rescue StandardError => e
        ["Can't chart: #{e.message}"]
      end

      # Left and right move along the cards, and up and down to the card in the same place in the row above or below.
      def move(name)
        return select(@cursor + (name == :left ? -1 : 1)) if %i[left right].include?(name)

        row = row_of(@cursor)
        target = @rows[(row + (name == :up ? -1 : 1)).clamp(0, [@rows.length - 1, 0].max)]
        select(target ? target[[@rows[row].index(@cursor), target.length - 1].min] : @cursor)
      end

      def row_of(index)
        @rows.index { it.include?(index) } || 0
      end

      def select(index)
        @cursor = index.clamp(0, [@charts.length - 1, 0].max)
        nil
      end

      def press(index, event)
        select(index)
        handle(event)
      end

      def open
        chart = selected
        [:open, chart.path, chart.line] if chart
      end
    end
  end
end
