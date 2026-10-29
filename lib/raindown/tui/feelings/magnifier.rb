# frozen_string_literal: true

require_relative '../../stat'

module Raindown
  module TUI
    # Code feelings' magnified digits: the method the mouse is over's, in purple and lavender by turns, so the digits
    # beside and below each other stand apart, each in a stat's block digits across its cell and the cells above and below
    # it, drawn over the grid.
    module Magnifier
      private

      # The lines with the digits of the method the mouse is over magnified, each across its cell and the cells above and
      # below it.
      def magnified(lines, cells, first, rows)
        magnified_cells(cells, first, rows).each do |index|
          magnify_cell(lines, (index / columns) - first, cells[index], index)
        end
        lines
      end

      # The cell's digit magnified over its row's line, the top one, and the lines above and below it.
      def magnify_cell(lines, top, owner, index)
        style = magnified_style(index)
        Stat::DIGITS[digit(owner, index).to_s].each_with_index do |text, line|
          magnify(lines, top + line, segment(text, style, width: FeelingsRenderer::CELL), 1 + (index % columns * FeelingsRenderer::CELL))
        end
      end

      # Purple and lavender in turn, along the cell's row and down its column, like a chessboard's squares.
      def magnified_style(index)
        return :feelings_purple if ((index / columns) + (index % columns)).odd?

        :feelings
      end

      # The cells of the rows from the first that are the method the mouse is over's, unless they're blank.
      def magnified_cells(cells, first, rows)
        (first * columns...(first + rows) * columns).select do |index|
          owner = cells[index]
          owner && navigator.hovered == Click.new(pane:, index: owner, action: :focus) && !hidden?(owner)
        end
      end

      # The segment over the line at the column, clicking whatever cell it covers, so the mouse over it is over that cell.
      def magnify(lines, line, segment, column)
        covered = segments_between(lines[line], column, column + display_width(segment.text)).first
        lines[line] = overlay_segments(lines[line], [segment.with(event: covered&.event)], column:)
      end
    end
  end
end
