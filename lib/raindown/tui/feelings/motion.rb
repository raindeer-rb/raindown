# frozen_string_literal: true

require 'zlib'

module Raindown
  module TUI
    # How Code feelings' digits move in their cells: the restless ones, the heaviest, now and then flicker one lower, and
    # the ones beside the method the mouse is over flee from it, to the far side of their cells, where they tremble often,
    # as if they're trying to escape, while every cell around it is bold, envious ones' cells too, in their own tint.
    module Motion
      # The columns a fleeing digit moves by when it trembles, each for a step of FLEEING_TREMBLE_SECONDS, a little longer
      # than a frame, so none are missed, once every FLEEING_TREMBLE_EVERY of them, about every 0.7 seconds, each cell at its
      # own moment.
      TREMBLE = [1, -1, 1, -1].freeze
      FLEEING_TREMBLE_SECONDS = 0.09
      FLEEING_TREMBLE_EVERY = 8
      # The columns a digit flees by, from the method beside it, from the middle of its cell, where it's still.
      FLEE = 1
      MIDDLE = 1
      # A restless digit flickers one lower for FLICKER_SECONDS, once every FLICKER_EVERY of them, about every 30 seconds.
      FLICKER_SECONDS = 0.5
      FLICKER_EVERY = 60
      # An envious method's cells' styles, for the styles they'd otherwise have.
      ENVY_STYLES = { feelings: :envy, nearby: :envy_nearby }.freeze

      private

      # The column of the cell's digit in its cell: the middle, or fleeing to its edge, where it trembles often.
      def digit_column(owner, index)
        away = flee(index)
        return MIDDLE if away.zero?

        fleeing_column(owner, index, away)
      end

      # At the edge of its cell it's fled to, trembling often and quickly, but never out of the cell.
      def fleeing_column(owner, index, away)
        (MIDDLE + away + tremble(owner, index)).clamp(0, FeelingsRenderer::CELL - 1)
      end

      # A column either way, during the cell's moment once every FLEEING_TREMBLE_EVERY steps, or else none.
      def tremble(owner, index)
        TREMBLE.fetch(((now / FLEEING_TREMBLE_SECONDS).floor + Zlib.crc32("#{owner}:#{index}")) % FLEEING_TREMBLE_EVERY, 0)
      end

      # One lower, during the restless cell's moment once every FLICKER_EVERY steps of FLICKER_SECONDS, or else none.
      def flicker(owner, index)
        return 0 if view.code_methods[owner].drift < FeelingsRenderer::RESTLESS
        return 0 unless (((now / FLICKER_SECONDS).floor + Zlib.crc32("#{owner}:#{index}")) % FLICKER_EVERY).zero?

        -1
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

      # An envious method's cells in their own tint, bold like the rest around the method the mouse is over.
      def tinted(owner, style)
        @envious ||= Hash.new { |envious, method| envious[method] = !view.envy(view.code_methods[method]).nil? }
        return style unless @envious[owner]

        ENVY_STYLES.fetch(style)
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
