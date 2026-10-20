# frozen_string_literal: true

require_relative 'drawing'

module Raindown
  class Chart < Node
    # A line of numbers from lowest to highest, or columns a cell high with negative values or a minus column
    # below a line.
    #   ▁▃▅█▂
    class Sparkline < Drawing
      SPARKS = %w[▁ ▂ ▃ ▄ ▅ ▆ ▇ █].freeze

      def lines
        return [@above.map { spark(it, *@above.minmax) }.join] if @below.none?(&:positive?)

        above, below = grid(1.0 / [@above.max, @below.max].max, slot: 1, gap: 0)
        [*above, '─' * @values.length, *below]
      end

      private

      def spark(value, low, high)
        SPARKS[high == low ? 0 : ((value - low) * 7.0 / (high - low)).round]
      end
    end
  end
end
