# frozen_string_literal: true

require 'zlib'

require_relative '../../stat'
require_relative '../scene'
require_relative 'bins'
require_relative 'code_box'
require_relative 'renderer'
require_relative 'waffle'

module Raindown
  module TUI
    # Code feelings, right of the files: the methods as clusters of digits in a grid, with the selected one highlighted
    # and its code below, then why it felt that way while that's typed, then the six bins and how many each holds.
    # When the batch is refined, it rains over them, then there's a waffle:
    #     0  0  2  2  2  5  5  9  9  9  9  1
    #     1  3  3  7  7  7  6  4  4  0  8  8
    #    ╭─ lib/text.rb:62 · Text#segments_between ──────────── changed 6× ─╮
    #    │ def segments_between(line, from, to)                              │
    #    ╰───────────────────────────────────────────────────────────────────╯
    #    ╭─ 01 ────╮ ╭─ 02 ────╮ ╭─ 03 ────╮ ╭─ 04 ────╮ ╭─ 05 ────╮ ╭─ 06 ────╮
    #    │ FROLIC  │ │ HOPE    │ │ NUMB    │ │ WOE     │ │ DREAD   │ │ MALICE  │
    #    │ ███░  9 │ │ ██░░  5 │ │ ████ 41 │ │ ██░░  6 │ │ █░░░  3 │ │ █░░░  2 │
    #    ╰─────────╯ ╰─────────╯ ╰─────────╯ ╰─────────╯ ╰─────────╯ ╰─────────╯
    class FeelingsRenderer < Renderer
      include Bins
      include CodeBox
      include Waffle

      # The columns and lines a cell takes, its digit small on the first line, with room around it for the digit magnified
      # in a stat's block digits, over the line above and the spaces beside it, when its method's selected or the mouse is
      # over it.
      CELL = 6
      CELL_LINES = 2
      # The code box's lines of code that a batch is sized for.
      FILLED_CODE_LINES = 1
      # The drift from which a method's cells flicker, and the ticks, half a second each, between a cell's flickers.
      RESTLESS = 7
      FLICKER_TICKS = 12
      # How far a cell's digit is from its method's drift, by its roll out of NOISE_ROLL, so about three in ten are off.
      NOISE = { 0 => -1, 1 => 1, 2 => -1, 3 => 1, 4 => -2, 5 => 2 }.freeze
      NOISE_ROLL = 20
      BUTTONS = [['Tab', 'Pane', :tab], ['1-6', 'Feel', nil], ['e', 'Edit', :edit], ['x', 'Fix', :execute],
                 ['/', 'Search', :search], ['q', 'Quit', :quit]].freeze

      def buttons = BUTTONS
      def page = 'Code feelings'

      # How much of the batch has been refined, on the right of the line above the panes.
      def spacer
        progress = "#{view.batch.progress} "
        progress_width = display_width(progress)
        padded([segment('', :blank, width: [width - progress_width, 0].max), segment(progress, :body, width: progress_width)])
      end

      # The cells come first, as the first draw picks the batch to fill them.
      def lines
        cells = view.cells(columns, filled_rows)
        return instead if view.code_methods.empty? || view.celebration

        below = [*code_box, *bins]
        (grid(cells, below.length) + below).first(height)
      end

      private

      def view = navigator.view

      # Instead of the grid, that there's nothing to feel, or rain and fireworks over the pane when the batch is refined,
      # then a waffle.
      def instead
        return blank(" No functions or methods in #{File.basename(navigator.root)} to feel") if view.code_methods.empty?
        return Scene.new(width:, height:).lines(view.celebration.frame) if view.animating?

        waffle
      end

      # The rows of the grid around the selected method's, each its cells' lines, below a blank line that leaves the first
      # row room to be magnified, above the lines below it, and blank lines for any left over.
      def grid(cells, below)
        lines = [height - below, 0].max
        rows = [(lines - 1) / CELL_LINES, 0].max
        first = first_row(cells, columns, rows)
        grid = magnified([padded([]), *grid_rows(cells, first, rows)], cells, first, rows)

        [*grid, *Array.new(lines - grid.length) { padded([]) }].first(lines)
      end

      # The cells' lines of the rows from the first.
      def grid_rows(cells, first, rows)
        Array.new(rows * CELL_LINES) { grid_line(cells, (first + (it / CELL_LINES)) * columns, columns, it % CELL_LINES) }
      end

      # The lines with the digits of the selected method, and the one the mouse is over, magnified, over the line above them
      # and beside them.
      def magnified(lines, cells, first, rows)
        magnified_cells(cells, first, rows).each do |index, click|
          top = ((index / columns) - first) * CELL_LINES
          Stat::DIGITS[digit(cells[index], index).to_s].each_with_index do |text, line|
            magnify(lines, top + line, segment(text, :feelings, width: 3, event: click), 2 + (index % columns * CELL))
          end
        end
        lines
      end

      # The cells of the rows from the first that are the selected method's, or the one the mouse is over's, with its click,
      # unless they're blank.
      def magnified_cells(cells, first, rows)
        (first * columns...(first + rows) * columns).filter_map do |index|
          owner = cells[index]
          click = Click.new(pane:, index: owner, action: :focus)
          [index, click] if owner && (owner == view.cursor || navigator.hovered == click) && !hidden?(owner)
        end
      end

      def magnify(lines, line, segment, column)
        lines[line] = overlay_segments(lines[line], [segment], column:)
      end

      def columns = [(width - 1) / CELL, 1].max

      # The grid's rows with a code box of FILLED_CODE_LINES, between its top and bottom, which a batch fills. A taller box
      # takes rows from the grid, which then scrolls to keep the selected method in view.
      def filled_rows = [(height - BIN_LINES - 3 - FILLED_CODE_LINES) / CELL_LINES, 1].max

      # The first row that shows, with the selected method's row in the middle where there's room.
      def first_row(cells, columns, rows)
        last = [((cells.length - 1) / columns) - rows + 1, 0].max
        ((cells.index(view.cursor).to_i / columns) - (rows / 2)).clamp(0, last)
      end

      # The cells' line of the row from the index.
      def grid_line(cells, from, columns, line)
        segments = (from...(from + columns)).filter_map do |index|
          owner = cells[index]
          next unless owner

          click = Click.new(pane:, index: owner, action: :focus)
          segment(cell_text(owner, index, line), :feelings, width: CELL, event: click)
        end
        padded([segment('', :blank, width: 1), *segments])
      end

      # The cell's line: its digit small on the first, or blank once its method's felt, but still there to select, which
      # shows it again with its code.
      def cell_text(owner, index, line)
        return ' ' * CELL if hidden?(owner) || line.nonzero?

        "  #{digit(owner, index)}   "
      end

      # Whether the method's felt, and not selected, so its cells are blank.
      def hidden?(owner) = owner != view.cursor && view.batch.felt?(view.code_methods[owner])

      # Near the method's drift, from 0 to 9: a cell's checksum rolls a small chance of it being one or two away.
      # A heavy method's cells also flicker one lower now and then, each at its own time, so they look restless.
      def digit(owner, index)
        drift = view.code_methods[owner].drift
        seed = Zlib.crc32("#{owner}:#{index}")
        digit = (drift + NOISE.fetch(seed % NOISE_ROLL, 0)).clamp(0, 9)
        return digit if drift < RESTLESS || ((view.tick + seed) % FLICKER_TICKS).nonzero?

        digit - 1
      end

      def blank(message)
        [[segment(message, :feelings)], *Array.new([height - 1, 0].max) { [segment('', :blank)] }].first(height)
      end
    end
  end
end
