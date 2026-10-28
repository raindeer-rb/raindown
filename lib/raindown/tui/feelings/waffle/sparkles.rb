# frozen_string_literal: true

require 'zlib'

require_relative 'baked_waffle'

module Raindown
  module TUI
    # Sparkles twinkling around the waffle, when a batch of code feelings is refined: white, on a ring just clear of it,
    # each growing from a dot to a star and back, then gone for a while, at its own time.
    #      ·         ✦
    #    ▄█████████████▄   ✧
    class Sparkles
      TWINKLE = %w[· ✧ ✦ ✧ ·].freeze
      COUNT = 10
      # The frames each of a twinkle's steps takes, and the steps between a sparkle's twinkles.
      TWINKLE_FRAMES = 3
      TWINKLE_EVERY = 16
      # The columns and lines the ring's clear of the waffle by.
      MARGIN = 3

      attr_reader :width, :height

      def initialize(width:, height:)
        @width = width
        @height = height
      end

      # Draws the sparkles twinkling by the tick into a Scene's cells.
      def draw(cells, tick)
        COUNT.times { sparkle(cells, Zlib.crc32("sparkle #{it}"), tick) }
      end

      private

      def sparkle(cells, seed, tick)
        char = TWINKLE[((tick / TWINKLE_FRAMES) + seed) % TWINKLE_EVERY]
        row, column = spot(seed)
        cells[row][column] = [char, :shine] if char && row.between?(0, height - 1) && column.between?(0, width - 1)
      end

      def spot(seed) = ring[seed % ring.length]

      # The spots on a ring just clear of the waffle, in the middle of the screen, by their row and column: along its top
      # and bottom, and down its sides.
      def ring
        @ring ||= begin
          top, left, bottom, right = corners
          [*(left..right).flat_map { [[top, it], [bottom, it]] }, *((top + 1)...bottom).flat_map { [[it, left], [it, right]] }]
        end
      end

      # The ring's top row, left column, bottom row and right column, MARGIN clear of the waffle.
      def corners
        left = (width - BakedWaffle.across) / 2 - MARGIN
        top = ((height - BakedWaffle.down) / 2) - MARGIN + 1
        [top, left, top + BakedWaffle.down + MARGIN, left + BakedWaffle.across + (MARGIN * 2) - 1]
      end
    end
  end
end
