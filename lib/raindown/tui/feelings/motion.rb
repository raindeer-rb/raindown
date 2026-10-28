# frozen_string_literal: true

require 'zlib'

module Raindown
  module TUI
    # How Code feelings' digits move in their cells: the restless ones, the heaviest, now and then tremble a column either
    # way for a moment, as if they're trying to escape, and the ones beside the method the mouse is over flee from it, to
    # the far side of their cells, where they tremble often, while every cell around it is bold.
    module Motion
      # The columns a digit moves by when it trembles, each for a step: a restless digit's steps are TREMBLE_SECONDS, and it
      # trembles once every TREMBLE_EVERY of them, about every minute, while a fleeing one's are twice as quick, and it
      # trembles once every FLEEING_TREMBLE_EVERY, about every 0.6 seconds, each cell at its own moment.
      TREMBLE = [1, -1, 1, -1].freeze
      TREMBLE_SECONDS = 0.15
      TREMBLE_EVERY = 400
      FLEEING_TREMBLE_SECONDS = 0.075
      FLEEING_TREMBLE_EVERY = 8
      # The columns a digit flees by, from the method beside it.
      FLEE = 2

      private

      # The column of the cell's digit in its cell, from the middle, fleeing to its edge, where it trembles often, or else
      # trembling now and then when it's restless.
      def digit_column(owner, index)
        away = flee(index)
        return fleeing_column(owner, index, away) if away.nonzero?
        return 2 if view.code_methods[owner].drift < FeelingsRenderer::RESTLESS

        2 + tremble(owner, index, TREMBLE_EVERY, TREMBLE_SECONDS)
      end

      # At the edge of its cell it's fled to, trembling often and quickly, but never out of the cell.
      def fleeing_column(owner, index, away)
        (2 + away + tremble(owner, index, FLEEING_TREMBLE_EVERY, FLEEING_TREMBLE_SECONDS)).clamp(0, FeelingsRenderer::CELL - 1)
      end

      # A column either way, during the cell's moment once every so many steps of the seconds, or else none.
      def tremble(owner, index, every, seconds)
        TREMBLE.fetch(((now / seconds).floor + Zlib.crc32("#{owner}:#{index}")) % every, 0)
      end

      # The time the frame's drawn at, in seconds, the same for all its cells.
      def now = @now ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Away from the method the mouse is over, when it's beside the cell in its row.
      def flee(index)
        away = 0
        away += FLEE if beside_hovered?(index, -1)
        away -= FLEE if beside_hovered?(index, 1)
        away
      end

      # Whether the cell a step along its row, -1 to the left or 1 to the right, is the method the mouse is over's, and
      # this one isn't.
      def beside_hovered?(index, step)
        ((index % columns) + step).between?(0, columns - 1) && hovered.include?(index + step) && !hovered.include?(index)
      end

      # Bold around the method the mouse is over, beside it, above it, below it, or diagonally.
      def cell_style(index)
        @nearby ||= hovered.flat_map { around(it) }.to_set - hovered
        return :nearby if @nearby.include?(index)

        :feelings
      end

      # The cells around the cell, in the rows above and below it and beside it in its own.
      def around(index)
        column = index % columns
        [-1, 0, 1].product([-1, 0, 1]).filter_map do |down, across|
          next if (down.zero? && across.zero?) || !(column + across).between?(0, columns - 1)

          index + (down * columns) + across
        end
      end

      # The cells of the method the mouse is over, by their index.
      def hovered
        @hovered ||= @cells.each_index.select { navigator.hovered == Click.new(pane:, index: @cells[it], action: :focus) }.to_set
      end
    end
  end
end
