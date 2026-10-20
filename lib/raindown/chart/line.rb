# frozen_string_literal: true

require_relative 'drawing'

module Raindown
  class Chart < Node
    # A line through the values in braille, where each character is a grid of dots 2 wide and 4 high,
    # with the highest and lowest values on the left, labels below and negative values below a line at zero.
    # With a minus column, its values are a second line below zero.
    #    4 ┤ ⠑⡄     ⢀⠎
    #    0 ┼──⠈⠢⡀──⡰⠁─
    #   -4 ┤    ⠘⢄⠎
    #        Jan   Mar
    class Line < Drawing
      BRAILLE = 0x2800
      # The bit of each dot in a braille character, by its row and then its column.
      DOTS = [[0x01, 0x08], [0x02, 0x10], [0x04, 0x20], [0x40, 0x80]].freeze

      def lines
        @series = @minus ? [@above, @below.map(&:-@)] : [@values]
        @low, @high = bounds
        @cells = Array.new(@height) { Array.new(@width, 0) }
        @series.each { plot_series(it) }

        [*axis, *label_line]
      end

      private

      def plot_series(values)
        dots = values.each_index.map { |index| [x(index), y(values[index])] }
        dots.each_cons(2) { |from, to| plot_line(*from, *to) }
        plot(*dots.first) if dots.one?
      end

      # The lowest and highest values, which include zero when there are negative values, so they go below its line.
      def bounds
        low, high = @series.flatten.minmax
        high = [high, 0].max if low.negative?

        [low, high]
      end

      def x(index)
        return 0 if @values.one?

        (index * ((@width * 2) - 1).to_f / (@values.length - 1)).round
      end

      def y(value)
        return (@height * 4) - 1 if @high == @low

        ((@high - value) * ((@height * 4) - 1).to_f / (@high - @low)).round
      end

      # The dots between two dots, a step at a time along whichever of across or down is longer.
      def plot_line(x_from, y_from, x_to, y_to)
        steps = [(x_to - x_from).abs, (y_to - y_from).abs, 1].max
        0.upto(steps) { |step| plot(between(x_from, x_to, step, steps), between(y_from, y_to, step, steps)) }
      end

      def between(from, to, step, steps)
        from + ((to - from) * step.to_f / steps).round
      end

      def plot(x, y) # rubocop:disable Naming/MethodParameterName -- a dot's coordinates
        @cells[y / 4][x / 2] |= DOTS[y % 4][x % 2]
      end

      # Each row of braille after the axis, with the highest value at the top, the lowest at the bottom,
      # and zero on the line through the negative values' row.
      def axis
        @ticks = ticks
        @tick_width = @ticks.values.map(&:length).max

        @cells.each_with_index.map do |cells, row|
          "#{@ticks[row].to_s.rjust(@tick_width)} #{mark(row)}#{cells.map { cell(it, row) }.join}"
        end
      end

      # The values on the axis by their row, where the highest wins a row it shares with the lowest.
      def ticks
        ticks = { (@height - 1) => number_text(@low) }
        ticks[0] = number_text(@high) unless @high == @low
        ticks[zero_row] ||= '0' if zero_row
        ticks
      end

      def mark(row)
        return '┼─' if row == zero_row

        @ticks[row] ? '┤ ' : '│ '
      end

      def zero_row
        y(0) / 4 if @low.negative?
      end

      def cell(bits, row)
        return (BRAILLE + bits).chr(Encoding::UTF_8) unless bits.zero?

        row == zero_row ? '─' : ' '
      end

      # The labels under their values, the first and last ones first, leaving out any that would touch another.
      def label_line
        return [] if @labels.all?(&:empty?)

        line = placed_labels.sort.reduce(+'') { |text, (from, _, label)| text << (' ' * (from - display_width(text))) << label }
        ["#{' ' * (@tick_width + 3)}#{line}"]
      end

      # Each label that fits, with where it starts and ends.
      def placed_labels
        [0, @labels.length - 1, *(1...(@labels.length - 1))].uniq.each_with_object([]) do |index, placed|
          span = label_span(index)
          placed << [*span, @labels[index]] if placed.none? { |from, to| span[0] <= to + 1 && span[1] >= from - 1 }
        end
      end

      # Where a label starts and ends, centered on its value's column and kept inside the chart.
      def label_span(index)
        width = display_width(@labels[index])
        from = ((x(index) / 2) - (width / 2)).clamp(0, [@width - width, 0].max)

        [from, from + width - 1]
      end
    end
  end
end
