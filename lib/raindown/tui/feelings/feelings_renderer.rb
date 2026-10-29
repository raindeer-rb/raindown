# frozen_string_literal: true

require 'zlib'

require_relative '../renderers/renderer'
require_relative 'bins'
require_relative 'code_box'
require_relative 'magnifier'
require_relative 'motion'
require_relative 'celebration/scene'
require_relative 'waffle/waffle'

module Raindown
  module TUI
    # Code feelings, right of the files: the methods as clusters of digits in a grid, with the selected one highlighted
    # and its code below, then why it felt that way while that's typed, then the five bins and how many each holds.
    # When the batch is refined, it rains over them, then there's a waffle:
    #     0  0  2  2  2  5  5  9  9  9  9  1
    #     1  3  3  7  7  7  6  4  4  0  8  8
    #    ╭─ lib/text.rb:62 · Text#segments_between ──────────── changed 6× ─╮
    #    │ def segments_between(line, from, to)                              │
    #    ╰───────────────────────────────────────────────────────────────────╯
    #    ╭─ 01 ────╮ ╭─ 02 ────╮ ╭─ 03 ────╮ ╭─ 04 ────╮ ╭─ 05 ────╮
    #    │ FROLIC  │ │ NUMB    │ │ WOE     │ │ DREAD   │ │ MALICE  │
    #    │ ███░  9 │ │ ████ 41 │ │ ██░░  6 │ │ █░░░  3 │ │ █░░░  2 │
    #    ╰─────────╯ ╰─────────╯ ╰─────────╯ ╰─────────╯ ╰─────────╯
    class FeelingsRenderer < Renderer
      include Bins
      include CodeBox
      include Magnifier
      include Motion
      include Waffle

      # The columns a cell takes, on a line of its own, its digit small in the middle, which is magnified in a stat's block
      # digits across the cell and over the cells above and below it when the mouse is over its method.
      CELL = 3
      # The drift from which a method's cells are restless, and flicker now and then.
      RESTLESS = 7
      # How far a cell's digit is from its method's drift, by its roll out of NOISE_ROLL, so about four in ten are off.
      NOISE = { 0 => -1, 1 => 1, 2 => -1, 3 => 1, 4 => -2, 5 => 2, 6 => -3, 7 => 3 }.freeze
      NOISE_ROLL = 20
      # The smallest grid that's worth refining, below which the pane's red, saying the screen's too small, under a
      # window with arrows out from its corners, when there's room for it.
      MIN_COLUMNS = 15
      MIN_ROWS = 5
      TOO_SMALL = 'Screen too small.'
      TOO_SMALL_ART = ['↖       ↗', '  ┌───┐  ', '  └───┘  ', '↙       ↘', ''].freeze
      BUTTONS = [['Tab', 'Pane', :tab], ['1-5', 'Feel', nil], ['e', 'Edit', :edit], ['x', 'Fix', :execute],
                 ['/', 'Search', :search], ['q', 'Quit', :quit]].freeze

      def buttons = BUTTONS
      def page = 'Code feelings'

      # How much of the batch has been refined, on the right of the line above the panes.
      def spacer
        progress = "#{view.batch.progress} "
        progress_width = display_width(progress)
        padded([segment('', :blank, width: [width - progress_width, 0].max), segment(progress, :body, width: progress_width)])
      end

      # The cells come first, as the first draw picks the batch to fill them, unless the screen's too small for a grid.
      def lines
        return too_small if too_small?

        cells = view.cells(columns, filled_rows)
        return instead if view.code_methods.empty? || view.celebration

        below = [*code_box, *bins]
        (grid(cells, below.length) + below).first(height)
      end

      private

      def view = navigator.view

      # Instead of the grid, that there's nothing to feel, or the celebration.
      def instead
        return blank(" No functions or methods in #{File.basename(navigator.root)} to feel") if view.code_methods.empty?

        celebration(view.celebration)
      end

      # Rain and fireworks over the pane when the batch is refined, then a waffle popping out, among confetti, balloons and
      # sparkles.
      def celebration(celebration)
        return Scene.new(width:, height:).lines(celebration.frame) if celebration.raining?

        waffle(Scene.new(width:, height:, animations: [Confetti, Balloons, Sparkles]).lines(celebration.popping), celebration.popping)
      end

      # The rows of the grid around the selected method's, between blank lines that leave the first and last rows room to
      # be magnified, above the lines below it, and blank lines for any left over.
      def grid(cells, below)
        @cells = cells
        lines = [height - below, 0].max
        rows = [lines - 2, 0].max
        first = first_row(cells, columns, rows)
        grid = magnified([padded([]), *grid_rows(cells, first, rows), padded([])], cells, first, rows)

        [*grid, *Array.new([lines - grid.length, 0].max) { padded([]) }].first(lines)
      end

      # The cells' lines of the rows from the first.
      def grid_rows(cells, first, rows) = Array.new(rows) { grid_line(cells, (first + it) * columns, columns) }

      def columns = [(width - 1) / CELL, 1].max

      # The grid's rows between its blank lines, above the code box, as tall as it always is until it's expanded, and the
      # bins, which a batch fills. An expanded box takes rows from the grid, which then scrolls to keep the selected method
      # in view.
      def filled_rows = [height - 2 - CODE_LINES - BOX_LINES - BIN_LINES, 1].max

      # The first row that shows, with the selected method's row in the middle where there's room.
      def first_row(cells, columns, rows)
        last = [((cells.length - 1) / columns) - rows + 1, 0].max
        ((cells.index(view.cursor).to_i / columns) - (rows / 2)).clamp(0, last)
      end

      # The cells' line of the row from the index.
      def grid_line(cells, from, columns)
        segments = (from...(from + columns)).filter_map do |index|
          owner = cells[index]
          next unless owner

          click = Click.new(pane:, index: owner, action: :focus)
          segment(cell_text(owner, index), grid_style(owner, index), width: CELL, event: click)
        end
        padded([segment('', :blank, width: 1), *segments])
      end

      # The cell's digit, small, where it moves, or blank once its method's felt, but still there to select, which shows it
      # again with its code.
      def cell_text(owner, index)
        return ' ' * CELL if hidden?(owner)

        column = digit_column(owner, index)
        "#{' ' * column}#{digit(owner, index)}#{' ' * (CELL - 1 - column)}"
      end

      # The selected method's cells, across the whole of each, on the selection's blue, so they join into one block, or on
      # green when it's already been felt, and others as they move.
      def grid_style(owner, index)
        return cell_style(index) unless owner == view.cursor
        return :felt_selected if view.batch.felt?(view.code_methods[owner])

        :feelings_selected
      end

      # Whether the method's felt, and not selected, so its cells are blank, asked once a frame for each method.
      def hidden?(owner)
        @hidden ||= Hash.new { |hidden, felt| hidden[felt] = felt != view.cursor && view.batch.felt?(view.code_methods[felt]) }
        @hidden[owner]
      end

      # Near the method's drift, from 0 to 9: a cell's checksum rolls a small chance of it being one to three away, and a
      # restless one flickers one lower now and then.
      def digit(owner, index)
        drift = view.code_methods[owner].drift
        (drift + NOISE.fetch(Zlib.crc32("#{owner}:#{index}") % NOISE_ROLL, 0)).clamp(0, 9) + flicker(owner, index)
      end

      def too_small? = columns < MIN_COLUMNS || filled_rows < MIN_ROWS

      # The pane in red, saying the screen's too small, in the middle, with the cells laid out without picking a batch for
      # so small a grid, so the keys still move between them.
      def too_small
        view.cells(columns)
        shown = [*TOO_SMALL_ART, TOO_SMALL]
        shown = [TOO_SMALL] if shown.length > height
        lines = Array.new(height, '')
        lines[(height - shown.length) / 2, shown.length] = shown
        lines.map { [segment(it.center(width), :too_small)] }
      end

      def blank(message)
        [[segment(message, :feelings)], *Array.new([height - 1, 0].max) { [segment('', :blank)] }].first(height)
      end
    end
  end
end
