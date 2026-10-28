# frozen_string_literal: true

module Raindown
  module TUI
    # The cells Code feelings' methods take in its grid, and how its cursor moves between them, along them and a row up
    # or down.
    module CellMoves
      # Each cell's method, by its index, in reading order, in a grid as many cells across as the columns.
      # They're kept, so up and down move a row.
      # The first time the grid's drawn, with its rows, right after the view opens, the batch is picked to fill them.
      def cells(columns, rows = nil)
        @week.fill(columns * rows) if rows
        @columns = columns
        @cells = code_methods.each_with_index.flat_map { |method, index| [index] * method.size }
      end

      private

      def move(by)
        self.cursor = @cursor + by
        nil
      end

      # To the method in the cell above or below the selected one's first cell.
      def move_row(by)
        cell = @cells[@cells.index(@cursor).to_i + (by * @columns)]
        self.cursor = cell if cell
        nil
      end
    end
  end
end
