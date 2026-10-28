# frozen_string_literal: true

require 'zlib'

require_relative 'balloons'
require_relative 'rain'

module Raindown
  module TUI
    # Confetti falling either side of the waffle, behind the balloons, when a batch of code feelings is refined: flecks in
    # bright colours, a row or two lower each frame, as fast as the Rain, wavering a column either way, then round again
    # from the top.
    #    ▪    ◆
    #       ·    ▴
    class Confetti
      FLECKS = %w[▪ ◆ ▴ ·].freeze
      # The columns for each fleck, and the frames each column it wavers takes.
      COLUMNS_A_FLECK = 3
      WAVER_FRAMES = 11

      attr_reader :width, :height

      def initialize(width:, height:)
        @width = width
        @height = height
      end

      # Draws the confetti where it's drifted to by the tick into a Scene's cells, clear of the waffle in the middle.
      def draw(cells, tick)
        (width / COLUMNS_A_FLECK).times { fleck(cells, Zlib.crc32("confetti #{it}"), tick) }
      end

      private

      def fleck(cells, seed, tick)
        column = drifted(seed, tick)
        return if clear?(column)

        cells[((tick * speed(seed)) + (seed >> 8)) % height][column] = look(seed)
      end

      # A row or two a frame, like the Rain's drops.
      def speed(seed) = ((seed >> 12) % 2) + 1

      # Its column, wavering a column either way as it falls.
      def drifted(seed, tick) = (seed % width) + (((tick / WAVER_FRAMES) + seed) % 3) - 1

      # Whether the column's in the middle, kept clear for the waffle, or off the screen.
      def clear?(column) = (column - (width / 2)).abs <= Balloons::MIDDLE / 2 || !column.between?(0, width - 1)

      # Its fleck and colour.
      def look(seed) = [FLECKS[(seed >> 4) % FLECKS.length], Rain::COLORS[(seed >> 16) % Rain::COLORS.length]]
    end
  end
end
