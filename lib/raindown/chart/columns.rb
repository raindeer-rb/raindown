# frozen_string_literal: true

require_relative 'drawing'

module Raindown
  class Chart < Node
    # Vertical columns from a line at zero, with negative values or a minus column below it,
    # the largest and smallest values on the left and labels below.
    #   2,210 ┤     ▄▄▄
    #         │ ███ ███
    #       0 ┼─────────
    #           Jan Feb
    class Columns < Drawing
      def lines
        low, high = range
        @slot = [3, *@labels.map { display_width(it) }].max
        above, below = grid(@height / (high - low).to_f, slot: @slot, gap: 1)
        top, bottom = ticks

        [*axis(above, top, at: 0), baseline, *axis(below, bottom, at: below.length - 1), *label_line]
      end

      private

      # The largest value at the top, and the smallest at the bottom when it's below zero.
      def ticks
        top = @above.max.positive? ? number_text(@above.max) : ''
        bottom = @below.max.positive? ? number_text(-@below.max) : ''
        @tick_width = [top, bottom, '0'].map(&:length).max

        [top, bottom]
      end

      # Rows after the axis, with the tick on the row at its index.
      def axis(rows, tick, at:)
        rows.each_with_index.map do |row, index|
          index == at && !tick.empty? ? "#{tick.rjust(@tick_width)} ┤ #{row}" : "#{' ' * @tick_width} │ #{row}"
        end
      end

      def baseline
        "#{'0'.rjust(@tick_width)} ┼#{'─' * ((@values.length * (@slot + 1)) + 1)}"
      end

      def label_line
        return [] if @labels.all?(&:empty?)

        ["#{' ' * (@tick_width + 3)}#{@labels.map { center(it, @slot) }.join(' ')}"]
      end
    end
  end
end
