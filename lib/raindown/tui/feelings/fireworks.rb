# frozen_string_literal: true

require 'zlib'

require_relative 'rain'

module Raindown
  module TUI
    # Fireworks, like over the Rain when a batch of code feelings is refined: rockets rising from the bottom, a row a
    # tick, that burst in a bright colour into sparks flying out eight ways, which fade, then another rises in their
    # place. Sparks fly twice as far across as up or down, as the cells are about twice as tall as they're wide:
    #     ·   ·   ·
    #      +  +  +
    #       * * *
    #   · + * * * + ·
    #       * * *
    #      +  +  +
    #     ·   ·   ·
    #         ╵
    #         ·
    class Fireworks
      # The columns for each rocket in the air at once.
      COLUMNS_A_ROCKET = 20
      # The sparks, a frame each, as they fly out from one in the middle and fade.
      SPARKS = %w[* * * + + · ·].freeze
      # The eight ways sparks fly, as columns and rows a frame.
      WAYS = [[-2, -1], [0, -1], [2, -1], [-2, 0], [2, 0], [-2, 1], [0, 1], [2, 1]].freeze
      # Where a rocket rises, the row it bursts on, and its colour.
      Rocket = Data.define(:column, :top, :color)

      attr_reader :width, :height

      def initialize(width:, height:)
        @width = width
        @height = height
      end

      # Draws the rockets and bursts at the tick into a Scene's cells, each rocket a tick apart from the others by a
      # checksum of it.
      def draw(cells, tick)
        [width / COLUMNS_A_ROCKET, 1].max.times do |rocket|
          launch, frame = (tick + Zlib.crc32("rocket #{rocket}")).divmod(height + SPARKS.length)
          firework(cells, rocket(Zlib.crc32("rocket #{rocket} #{launch}")), frame)
        end
      end

      private

      # A rocket, from the seed, a checksum of it and how many it's launched, bursting in the top half or so.
      def rocket(seed)
        Rocket.new(column: seed % width, top: (height / 5) + ((seed >> 8) % [height / 3, 1].max),
                   color: Rain::COLORS[(seed >> 16) % Rain::COLORS.length])
      end

      # The rocket rising, with a spark trailing it, or once it's as high as it goes, bursting.
      def firework(cells, rocket, frame)
        rising = height - 1 - rocket.top
        return burst(cells, rocket, frame - rising) if frame >= rising

        put(cells, rocket.column, height - 1 - frame, '╵', rocket.color)
        put(cells, rocket.column, height - frame, '·', rocket.color)
      end

      def burst(cells, rocket, frame)
        return unless (spark = SPARKS[frame])

        WAYS.each { |across, down| put(cells, rocket.column + (across * frame), rocket.top + (down * frame), spark, rocket.color) }
      end

      def put(cells, column, row, char, color)
        cells[row][column] = [char, color] if row.between?(0, height - 1) && column.between?(0, width - 1)
      end
    end
  end
end
