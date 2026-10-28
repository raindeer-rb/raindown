# frozen_string_literal: true

require_relative '../text'
require_relative 'balloons'
require_relative 'confetti'
require_relative 'fireworks'
require_relative 'rain'
require_relative 'sparkles'

module Raindown
  module TUI
    # Animations drawn over each other, each into the same cells, a character and its style each, in turn, so the later
    # ones are on top, like Fireworks over the Rain.
    class Scene
      include Text

      attr_reader :width, :height

      def initialize(width:, height:, animations: [Rain, Fireworks])
        @width = width
        @height = height
        @animations = animations.map { it.new(width:, height:) }
      end

      # The lines at the tick, as segments.
      def lines(tick)
        cells = Array.new(height) { Array.new(width) { [' ', :blank] } }
        @animations.each { it.draw(cells, tick) }
        cells.map { segments(it) }
      end

      private

      # The row's runs of cells in the same style, a segment each.
      def segments(row)
        row.chunk_while { |cell, after| cell[1] == after[1] }.map { Segment.new(text: it.map(&:first).join, style: it[0][1], event: nil) }
      end
    end
  end
end
