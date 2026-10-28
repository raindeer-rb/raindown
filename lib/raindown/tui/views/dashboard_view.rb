# frozen_string_literal: true

require_relative '../events'

module Raindown
  module TUI
    # Every chart in the projects' Markdown files, drawn from its data by its project's Worker, as cards in a grid
    # with a cursor. A chart is a chart: directive, or a project's own node that's a Raindown::Chart,
    # like "Sales < Raindown::Chart". Charts are drawn again every few seconds, so they follow changes to their data,
    # like a CSV file, without a save.
    # A key's next step, for the Navigator, is nil, or an Open or Edit of a chart's directive.
    class DashboardView
      # Seconds between drawing the charts again.
      REDRAW = 2
      MOVES = %i[up down left right].freeze
      # Columns between the cards, and the narrowest a card is, with its border.
      GAP = 2
      MIN_CARD_WIDTH = 28

      attr_reader :root, :errors, :cursor, :project

      def initialize(root:, workers:)
        @root = root
        @workers = workers
        @cursor = 0
        @offset = 0
        @rows = []
      end

      def renderer = DashboardRenderer
      def target = self
      def path = nil
      def changed? = false
      def typing? = false
      def animating? = false

      def status(_navigator)
        found = "#{charts.length} #{charts.length == 1 ? 'chart' : 'charts'} in #{File.basename(project || root)}"
        errors.empty? ? [:info, found] : [:error, "#{found}, but couldn't read #{errors.join(', ')}"]
      end

      # Finds the charts again, like when it's opened, or a file is saved or added.
      def load
        draw(find: true)
        @cursor = @cursor.clamp(0, [charts.length - 1, 0].max)
      end

      # The charts, as each project's Worker drew them, of the project they're narrowed to, if any.
      def charts
        project ? @cards.filter { it.project == project } : @cards
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

      # The charts' indexes in rows, as many of a project's as fit across the width after a column of margin, with each
      # project's charts starting a row. They're kept, so up and down move a row.
      def rows(width)
        @rows = charts.each_index.chunk_while { |a, b| charts[a].project == charts[b].project }.flat_map { group_rows(it, width) }
      end

      # The widths a card can be: no narrower than MIN_CARD_WIDTH, when there's room, and no wider than the width.
      def card_widths(width) = [MIN_CARD_WIDTH, width - 1].min..(width - 1)

      def selected = charts[@cursor]

      def first_in_row?
        @rows.empty? || @rows.any? { it.first == @cursor }
      end

      # Every key but Tab to the files, or left from the first card in a row.
      def next_step?(key) = !%i[tab tick].include?(key) && !(key == :left && first_in_row?)

      def next_step(key)
        chart = selected
        case key
        when *MOVES then move(key).then { nil }
        when :enter then chart && Open.new(path: chart.path, line: chart.line)
        when :edit then chart && Edit.new(path: chart.path, line: chart.line)
        when :reload then load.then { nil }
        end
      end

      def cursor=(index)
        @cursor = index.clamp(0, [charts.length - 1, 0].max)
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

      def group_rows(indexes, width)
        indexes.each_with_object([[]]) do |index, rows|
          rows << [] if rows.last.any? && row_width(rows.last + [index], width) > width
          rows.last << index
        end
      end

      # A row of cards' width, after a column of margin, with a gap between each.
      def row_width(row, width)
        1 + row.sum { charts[it].box_width(within: card_widths(width)) } + (GAP * (row.length - 1))
      end

      # Left and right move along the cards, and up and down to the card in the same place in the row above or below.
      def move(name)
        return self.cursor = @cursor + (name == :left ? -1 : 1) if %i[left right].include?(name)

        row = row_of(@cursor)
        target = @rows[(row + (name == :up ? -1 : 1)).clamp(0, [@rows.length - 1, 0].max)]
        self.cursor = target ? target[[@rows[row].index(@cursor), target.length - 1].min] : @cursor
      end

      def row_of(index)
        @rows.index { it.include?(index) } || 0
      end
    end
  end
end
