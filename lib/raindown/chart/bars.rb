# frozen_string_literal: true

require_relative 'drawing'

module Raindown
  class Chart < Node
    # Horizontal bars, with negative values left of a line:
    #   Jan  ████████████▍    1,240
    class Bars < Drawing
      LEFT = ['', '▏', '▎', '▍', '▌', '▋', '▊', '▉'].freeze
      # Negative bars fill a cell from the right, which only has eighths and halves.
      RIGHT = ['', '▕', '▕', '▐', '▐', '▐', FULL, FULL].freeze

      def lines
        low, high = range
        @scale = @width / (high - low).to_f
        @left = cells(-low * @scale)
        @right = cells(high * @scale)
        @line = low.negative? ? '│' : ''

        @labels.zip(@values, value_texts).map { |label, value, text| "#{bar_line(label, value)} #{text}" }
      end

      private

      def value_texts
        texts = @values.map { number_text(it) }
        texts.map { it.rjust(texts.map(&:length).max) }
      end

      def bar_line(label, value)
        negative = value.negative? ? bar(-value * @scale, RIGHT, from: :right) : ''
        positive = value.positive? ? bar(value * @scale, LEFT) : ''

        "#{label_text(label)}#{negative.rjust(@left)}#{@line}#{pad(positive, @right)}"
      end

      def label_text(label)
        label_width = @labels.map { display_width(it) }.max
        label_width.zero? ? '' : "#{pad(label, label_width)}  "
      end

      # A bar of full cells and an eighth, where any value above zero shows.
      def bar(length, partials, from: :left)
        eighths = (length * 8).round.clamp(1..)
        full, part = eighths.divmod(8)

        from == :left ? (FULL * full) + partials[part] : partials[part] + (FULL * full)
      end
    end
  end
end
