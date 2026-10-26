# frozen_string_literal: true

module Raindown
  module TUI
    # Every chart in the projects' Markdown files, drawn from its data by its project's Worker, as cards in a grid
    # with a cursor. A chart is a chart: directive, or a project's own node that's a Raindown::Chart,
    # like "Sales < Raindown::Chart". Charts are drawn again every few seconds, so they follow changes to their data,
    # like a CSV file, without a save.
    # Handle returns the Navigator's next step: nil, or [:open, path, line] or [:edit, path, line] for a chart's directive.
    class Dashboard
      # Seconds between drawing the charts again.
      REDRAW = 2
      MOVES = %i[up down left right].freeze

      attr_reader :root, :errors, :cursor, :project
      # The cards' indexes in each row, which the Layout sets as it draws them, so up and down move a row.
      attr_writer :rows

      def initialize(root:, workers:)
        @root = root
        @workers = workers
        @cursor = 0
        @offset = 0
        @rows = []
        load
      end

      # Finds the charts again, like when a file is saved or added.
      def load
        draw(find: true)
        @cursor = @cursor.clamp(0, [charts.length - 1, 0].max)
      end

      # The charts, as each project's Worker drew them, of the project they're narrowed to, if any.
      def charts
        project ? @cards.select { it.project == project } : @cards
      end

      # Narrows the charts to a project's, or with nil, shows every project's.
      def project=(project)
        @project = project
        @cursor = 0
        @offset = 0
      end

      def cards
        draw if Process.clock_gettime(Process::CLOCK_MONOTONIC) - @drawn_at >= REDRAW
        charts
      end

      def selected = charts[@cursor]

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

      def draw(find: false)
        @cards = []
        @errors = []
        @workers.each do |worker|
          answer = worker.call(:charts, find:)
          @cards.concat(answer[:cards])
          @errors.concat(answer[:errors])
        rescue Worker::Error => e
          @errors << "#{File.basename(worker.root)}: #{e.message}"
        end
        @cards.sort_by! { [it.project, it.path, it.line] }
        @drawn_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
        @cursor = index.clamp(0, [charts.length - 1, 0].max)
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
