# frozen_string_literal: true

require_relative 'drawing'

module Raindown
  class Chart < Node
    # Horizontal bars, with negative values or a minus column left of a line:
    #   Jan  ████████████▍    1,240        a1b2c3d  -38 ▕████│███████████▍  +142
    class Bars < Drawing
      LEFT = ['', '▏', '▎', '▍', '▌', '▋', '▊', '▉'].freeze
      # Negative bars fill a cell from the right, which only has eighths and halves.
      RIGHT = ['', '▕', '▕', '▐', '▐', '▐', FULL, FULL].freeze

      def lines
        measure
        values = value_texts
        minuses = minus_texts
        @labels.each_index.map { |index| "#{label_text(@labels[index])}#{minuses[index]}#{bar_line(index)} #{values[index]}" }
      end

      private

      # How many characters a value takes, and how many the bars take either side of the line.
      def measure
        low, high = range
        @scale = @width / (high - low).to_f
        @left = cells(-low * @scale)
        @right = cells(high * @scale)
        @line = low.negative? ? '│' : ''
      end

      # Each minus value lined up left of its bar, or nothing without a minus column.
      def minus_texts
        return Array.new(@labels.length, '') unless @minus

        aligned(@below.map { "-#{number_text(it)}" }).map { "#{it} " }
      end

      # Each value, lined up, with a + when a minus column is charted against it, whose values go left of the bars.
      def value_texts
        aligned(@minus ? @above.map { "+#{number_text(it)}" } : @values.map { number_text(it) })
      end

      def aligned(texts)
        texts.map { it.rjust(texts.map(&:length).max) }
      end

      def bar_line(index)
        negative = @below[index].positive? ? bar(@below[index] * @scale, RIGHT, from: :right) : ''
        positive = @above[index].positive? ? bar(@above[index] * @scale, LEFT) : ''

        "#{negative.rjust(@left)}#{@line}#{pad(positive, @right)}"
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
