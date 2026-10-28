# frozen_string_literal: true

require 'zlib'

require_relative '../scene'
require_relative 'code_box'
require_relative 'renderer'
require_relative 'waffle'

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
    #    │ WOE     │ │ FROLIC  │ │ DREAD   │ │ MALICE  │ │ NUMB    │
    #    │ ██░░  6 │ │ ███░  9 │ │ █░░░  3 │ │ █░░░  2 │ │ ████ 41 │
    #    ╰─────────╯ ╰─────────╯ ╰─────────╯ ╰─────────╯ ╰─────────╯
    class FeelingsRenderer < Renderer
      include CodeBox
      include Waffle

      # Columns a digit takes, with a space either side.
      CELL = 3
      # The bins' lines, and the code box's lines of code that a batch is sized for.
      BIN_LINES = 4
      FILLED_CODE_LINES = 1
      # The drift from which a method's cells flicker, and the ticks, half a second each, between a cell's flickers.
      RESTLESS = 7
      FLICKER_TICKS = 12
      # How far a cell's digit is from its method's drift, by its roll out of NOISE_ROLL, so about three in ten are off.
      NOISE = { 0 => -1, 1 => 1, 2 => -1, 3 => 1, 4 => -2, 5 => 2 }.freeze
      NOISE_ROLL = 20
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

      # The rows of the grid around the selected method's, above the lines below it.
      def grid(cells, below)
        rows = [height - below, 0].max
        first = first_row(cells, columns, rows)

        Array.new(rows) { |row| grid_line(cells, (first + row) * columns, columns) }
      end

      def columns = [(width - 1) / CELL, 1].max

      # The grid's rows with a code box of FILLED_CODE_LINES, between its top and bottom, which a batch fills. A taller box
      # takes rows from the grid, which then scrolls to keep the selected method in view.
      def filled_rows = [height - BIN_LINES - 2 - FILLED_CODE_LINES, 1].max

      # The first row that shows, with the selected method's row in the middle where there's room.
      def first_row(cells, columns, rows)
        last = [((cells.length - 1) / columns) - rows + 1, 0].max
        ((cells.index(view.cursor).to_i / columns) - (rows / 2)).clamp(0, last)
      end

      def grid_line(cells, from, columns)
        segments = (from...(from + columns)).filter_map do |index|
          owner = cells[index]
          next unless owner

          click = Click.new(pane:, index: owner, action: :focus)
          segment(cell_text(owner, index), cell_style(owner, click), width: CELL, event: click)
        end
        padded([segment('', :blank, width: 1), *segments])
      end

      # The cell's digit, or blank once its method's felt, but still there to select, which shows it again with its code.
      def cell_text(owner, index)
        return ' ' * CELL if owner != view.cursor && view.batch.felt?(view.code_methods[owner])

        " #{digit(owner, index)} "
      end

      # The selected method highlighted, and the one the mouse is over in bold blue.
      def cell_style(owner, click)
        return :selected if owner == view.cursor
        return :hover if navigator.hovered == click

        :menu
      end

      # Near the method's drift, from 0 to 9: a cell's checksum rolls a small chance of it being one or two away.
      # A heavy method's cells also flicker one lower now and then, each at its own time, so they look restless.
      def digit(owner, index)
        drift = view.code_methods[owner].drift
        seed = Zlib.crc32("#{owner}:#{index}")
        digit = (drift + NOISE.fetch(seed % NOISE_ROLL, 0)).clamp(0, 9)
        return digit if drift < RESTLESS || ((view.tick + seed) % FLICKER_TICKS).nonzero?

        digit - 1
      end

      # The five bins, each a box with its number, its temper, and a bar of how many feelings it holds.
      def bins
        counts = view.log.counts
        most = [counts.values.max, 1].max
        chosen = chosen_temper
        boxes = counts.each_with_index.map { |(temper, count), index| bin(index + 1, temper, count, most, chosen) }

        Array.new(BIN_LINES) do |line|
          padded([segment('', :blank, width: 1), *boxes.flat_map { [it[line], segment(' ', :blank, width: 1)] }])
        end
      end

      # The temper being noted, or else how the selected method felt, if it's been felt.
      def chosen_temper = view.noting || view.log.temper(view.selected)

      # As wide as five fit, which cuts their borders short in a pane too narrow for them.
      def bin_width = [(width - 6) / 5, 1].max

      # The bin's lines, highlighted when it's the chosen temper: the one being noted, or how the selected method felt.
      def bin(number, temper, count, most, chosen)
        style = :border
        style = :selected if temper == chosen
        lines = ["╭─ 0#{number} #{'─' * [bin_width - 7, 0].max}╮", "│ #{temper.upcase.ljust(bin_width - 4)} │",
                 "│ #{bar(count, most)} #{count} │", "╰#{'─' * (bin_width - 2)}╯"]

        lines.map { segment(it, style, width: bin_width) }
      end

      # As long as there's room beside the count, and filled as far as its share of the fullest bin's.
      def bar(count, most)
        length = bin_width - 5 - count.to_s.length
        filled = (length * count / most.to_f).round
        "#{'█' * filled}#{'░' * (length - filled)}"
      end

      def blank(message)
        [[segment(message, :info)], *Array.new([height - 1, 0].max) { [segment('', :blank)] }].first(height)
      end
    end
  end
end
