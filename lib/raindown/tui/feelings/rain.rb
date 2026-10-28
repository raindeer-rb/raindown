# frozen_string_literal: true

require 'zlib'

module Raindown
  module TUI
    # Rain, like when a batch of code feelings is refined: drops falling down some of the columns, each at its own speed
    # and in a bright colour of its own, that splash and spread when they hit the bottom, then fall again from the top
    # in another colour:
    #       │          ╎
    #       ╎    │          │
    #     │     ╎        │
    #    · ·   ◦       .   .
    class Rain
      # One column in RAINY has a drop.
      RAINY = 4
      # The splash, a frame each after a drop hits the bottom, as its distance either side of the drop's column.
      SPLASH = [[0, '◦'], [1, '·'], [2, '.']].freeze
      COLORS = %i[bright_red bright_orange bright_yellow bright_green bright_cyan bright_blue bright_purple bright_pink].freeze

      attr_reader :width, :height

      def initialize(width:, height:)
        @width = width
        @height = height
      end

      # Draws the drops at the tick into a Scene's cells.
      def draw(cells, tick)
        width.times { drop(cells, it, Zlib.crc32("rain #{it}"), tick) }
      end

      private

      # The column's drop, if it has one, from the seed, a checksum of the column, like how fast it falls and when it
      # starts.
      def drop(cells, column, seed, tick)
        return unless (seed % RAINY).zero?

        falling = (height + speed(seed) - 1) / speed(seed)
        fallen, frame = (tick + (seed >> 8)).divmod(falling + SPLASH.length)
        color = color(column, fallen)
        return splash(cells, column, frame - falling, color) if frame >= falling

        fall(cells, column, frame * speed(seed), color)
      end

      # A row or two a tick.
      def speed(seed) = ((seed >> 4) % 2) + 1

      # A colour each time the column's drop falls, from a checksum of how many times it has.
      def color(column, fallen) = COLORS[Zlib.crc32("#{column} #{fallen}") % COLORS.length]

      # The drop at the row, and its tail above it.
      def fall(cells, column, row, color)
        cells[row][column] = ['│', color]
        cells[row - 1][column] = ['╎', color] if row.positive?
      end

      def splash(cells, column, frame, color)
        spread, char = SPLASH[frame]
        [column - spread, column + spread].uniq.each { cells[height - 1][it] = [char, color] if it.between?(0, width - 1) }
      end
    end
  end
end
