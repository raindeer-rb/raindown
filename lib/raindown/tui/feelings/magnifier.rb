# frozen_string_literal: true

require_relative '../../stat'

module Raindown
  module TUI
    # Code feelings' magnified digits: the selected method's, on the selection's blue, and the one the mouse is over's,
    # each in a stat's block digits across its whole cell and the blank line above it, drawn over the grid.
    module Magnifier
      private

      # The lines with the digits of the selected method, and the one the mouse is over, magnified, over the line above them
      # and beside them, each across its whole cell and the line above it.
      def magnified(lines, cells, first, rows)
        magnified_cells(cells, first, rows).each do |index, click|
          magnify_cell(lines, ((index / columns) - first) * FeelingsRenderer::CELL_LINES, cells[index], index, click)
        end
        lines
      end

      # The cell's digit magnified over the lines from the top one, across the whole cell.
      def magnify_cell(lines, top, owner, index, click)
        style = magnified_style(owner)
        Stat::DIGITS[digit(owner, index).to_s].each_with_index do |text, line|
          segment = segment(" #{text}  ", style, width: FeelingsRenderer::CELL, event: click)
          magnify(lines, top + line, segment, 1 + (index % columns * FeelingsRenderer::CELL))
        end
      end

      # The selected method's cells, across the whole of each, on the selection's blue, so they join into one block, or on
      # green when it's already been felt.
      def magnified_style(owner)
        return :feelings unless owner == view.cursor
        return :felt_selected if view.batch.felt?(view.code_methods[owner])

        :selected
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
    end
  end
end
