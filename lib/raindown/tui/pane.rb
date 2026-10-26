# frozen_string_literal: true

module Raindown
  module TUI
    # A pane's cursor and how far it's scrolled, over rows that can change between draws, like when a folder folds.
    class Pane
      attr_writer :cursor

      def initialize(&rows)
        @rows = rows
        @cursor = 0
        @offset = 0
      end

      def rows = @rows.call
      def selected = rows[cursor]

      # The cursor stays on a row when there are fewer rows than before.
      def cursor
        @cursor.clamp(0, [rows.length - 1, 0].max)
      end

      # Moves past rows that can't be selected, like separators, and stays at the first or last row rather than moving off them.
      def move(by)
        rows = self.rows
        index = cursor + by
        index += by while index.between?(0, rows.length - 1) && !rows[index].selectable?
        @cursor = index if index.between?(0, rows.length - 1)
      end

      def reset
        @cursor = 0
        @offset = 0
      end

      # The rows that fit in the height, scrolled so the cursor's row is one of them, and the first one's index.
      def visible(height)
        cursor = self.cursor
        @offset = @offset.clamp([cursor - height + 1, 0].max, cursor)

        [rows[@offset, height] || [], @offset]
      end
    end
  end
end
