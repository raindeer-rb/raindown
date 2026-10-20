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

      # Values go above zero or right of its line, and negative values below or left of it. With a minus column,
      # each point is [label, value, minus], and its value goes above and its minus below, whatever their signs.
      def initialize(points, width:, height:)
        @labels = points.map { it.first.to_s }
        @values = points.map { it[1] }
        @minus = points.map { it[2] } if points.any? { it.length > 2 }
        @above = @minus ? @values.map(&:abs) : @values.map { it.clamp(0..) }
        @below = @minus ? @minus.map(&:abs) : @values.map { (-it).clamp(0..) }
        @width = width
        @height = height
      end

      private

      # How far below and above zero the chart goes, which always includes zero, so bars and columns start from it.
      def range
        low = -@below.max
        high = @above.max

        [low, low == high ? 1 : high]
      end

      # The rows of columns above and below zero, top to bottom, each column in the middle of its slot.
      def grid(scale, slot:, gap:)
        low, high = range

        [grid_rows(cells(high * scale).downto(1), @above, scale, LOWER, slot:, gap:),
         grid_rows(1.upto(cells(-low * scale)), @below, scale, UPPER, slot:, gap:)]
      end

      # Each row by how many cells it is from zero, for the values above it or below it.
      def grid_rows(rows, values, scale, partials, slot:, gap:) # rubocop:disable Metrics/ParameterLists -- a row of the grid
        rows.map do |row|
          values.map { |value| center(cell((value * scale) - row + 1, partials) * [slot, 3].min, slot) }.join(' ' * gap)
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
