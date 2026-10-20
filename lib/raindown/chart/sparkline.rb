# frozen_string_literal: true

require_relative 'drawing'

module Raindown
  class Chart < Node
    # A line of numbers from lowest to highest, or columns a cell high with negative values below a line.
    #   ▁▃▅█▂
    class Sparkline < Drawing
      SPARKS = %w[▁ ▂ ▃ ▄ ▅ ▆ ▇ █].freeze

      def lines
        low, high = @values.minmax
        return [@values.map { spark(it, low, high) }.join] unless low.negative?

        above, below = grid(1.0 / [high, -low].max, slot: 1, gap: 0)
        [*above, '─' * @values.length, *below]
      end

      private

      def spark(value, low, high)
        SPARKS[high == low ? 0 : ((value - low) * 7.0 / (high - low)).round]
      end
    end
  end
end
