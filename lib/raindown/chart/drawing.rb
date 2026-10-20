# frozen_string_literal: true

require 'unicode/display_width'

require_relative '../node'

module Raindown
  class Chart < Node
    class Drawing
      FULL = '█'
      # Columns fill a cell from the bottom, and negative columns from the top, which only has eighths and halves.
      LOWER = ['', '▁', '▂', '▃', '▄', '▅', '▆', '▇'].freeze
      UPPER = ['', '▔', '▔', '▀', '▀', '▀', FULL, FULL].freeze
      # Float error, so a value of exactly 3 cells doesn't reach into a 4th.
      EPSILON = 1e-9

      def initialize(points, width:, height:)
        @labels = points.map { it.first.to_s }
        @values = points.map(&:last)
        @width = width
        @height = height
      end

      private

      # The lowest and highest values, which always include zero, so bars and columns start from it.
      def range
        low = [@values.min, 0].min
        high = [@values.max, 0].max

        [low, low == high ? 1 : high]
      end

      # The rows of columns above and below zero, top to bottom, each column in the middle of its slot.
      def grid(scale, slot:, gap:)
        low, high = range

        [grid_rows(cells(high * scale).downto(1), scale, LOWER, slot:, gap:),
         grid_rows(1.upto(cells(-low * scale)), -scale, UPPER, slot:, gap:)]
      end

      # Each row by how many cells it is from zero, where a negative scale draws the negative values.
      def grid_rows(rows, scale, partials, slot:, gap:)
        rows.map do |row|
          @values.map { |value| center(cell((value * scale) - row + 1, partials) * [slot, 3].min, slot) }.join(' ' * gap)
        end
      end

      # How much of a cell a column fills, by eighths, where any value above zero shows.
      def cell(level, partials)
        return ' ' if level <= EPSILON

        eighths = (level.clamp(..1) * 8).round.clamp(1..)
        eighths == 8 ? FULL : partials[eighths]
      end

      def cells(length)
        (length - EPSILON).ceil.clamp(0..)
      end

      # Whole numbers with thousands separators, and others to two decimal places.
      def number_text(value)
        value = value.round(2)
        value = value.to_i if value.is_a?(Float) && value == value.to_i
        whole, decimal = value.abs.to_s.split('.')

        "#{'-' if value.negative?}#{whole.reverse.scan(/\d{1,3}/).join(',').reverse}#{".#{decimal}" if decimal}"
      end

      def display_width(text)
        Unicode::DisplayWidth.of(text)
      end

      def pad(text, width)
        text + (' ' * (width - display_width(text)))
      end

      def center(text, width)
        pad((' ' * ((width - display_width(text)) / 2)) + text, width)
      end
    end
  end
end
