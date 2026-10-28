# frozen_string_literal: true

require 'zlib'

require_relative 'rain'

module Raindown
  module TUI
    # Balloons floating up either side of the waffle, when a batch of code feelings is refined: one for every so many
    # columns, left and right in turn, clear of the waffle in the middle, each in a bright colour, shaded where the light
    # catches it, with a knot and a string that kinks, rising from below the bottom, swaying a column either way, then
    # round again. Their spaces are see-through:
    #     ▄███▄
    #    █░▒████
    #    █▒█████
    #     ▀███▀
    #       ▼
    #       │
    #       ╰╮
    #        │
    class Balloons
      BALLOON = [' ▄███▄', '█░▒████', '█▒█████', ' ▀███▀', '   ▼'].freeze
      STRING = ['   │', '   ╰╮', '    │'].freeze
      # The columns for each balloon, and the frames each row it rises takes.
      COLUMNS_A_BALLOON = 20
      # The columns kept clear in the middle, for the waffle and its text.
      MIDDLE = 39
      RISE_FRAMES = 2.1
      # Where a balloon is, by its left column and its top row, and its colour.
      Balloon = Data.define(:left, :top, :color)

      attr_reader :width, :height

      def initialize(width:, height:)
        @width = width
        @height = height
      end

      # Draws the balloons where they've floated to by the tick into a Scene's cells.
      def draw(cells, tick)
        [width / COLUMNS_A_BALLOON, 2].max.times { balloon(cells, floated(it, Zlib.crc32("balloon #{it}"), tick)) }
      end

      private

      # Where a balloon's floated to by the tick, from its seed, a checksum of it: where it rises in its side, when it starts,
      # how it sways, never past an edge, and its colour.
      def floated(number, seed, tick)
        sway = (side(number, seed) + Math.sin((tick + seed) / 6.4).round).clamp(0, [width - BALLOON.map(&:length).max, 0].max)
        Balloon.new(left: sway, top: risen(seed, tick),
                    color: Rain::COLORS[(seed >> 16) % Rain::COLORS.length])
      end

      # A column in the left side for the even balloons, and the right for the odd, either side of the middle.
      def side(number, seed)
        room = [((width - MIDDLE) / 2) - BALLOON.map(&:length).max, 1].max
        column = seed % room
        return column if number.even?

        width - room + column - BALLOON.map(&:length).max
      end

      # Its top row, a row higher every RISE_FRAMES, from below the bottom to above the top, then round again.
      def risen(seed, tick) = height - 1 - (((tick / RISE_FRAMES).floor + (seed >> 8)) % (height + BALLOON.length + STRING.length))

      def balloon(cells, balloon)
        BALLOON.each_with_index { |text, row| put(cells, balloon.top + row, balloon.left, text, balloon.color) }
        STRING.each_with_index { |text, row| put(cells, balloon.top + BALLOON.length + row, balloon.left, text, :border) }
      end

      # The text's characters from the left column, leaving the cells under its spaces as they are.
      def put(cells, row, left, text, style)
        return unless row.between?(0, height - 1)

        text.each_char.with_index do |char, at|
          cells[row][left + at] = [char, style] if char != ' ' && (left + at).between?(0, width - 1)
        end
      end
    end
  end
end
