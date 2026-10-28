# frozen_string_literal: true

module Raindown
  module TUI
    # When a batch of code feelings is refined, like Severance's waffle party: rain, a frame each tick, for about five
    # seconds of the Screen's 60 ms frames, then a waffle, until a key's pressed.
    class Celebration
      RAIN_FRAMES = 83

      attr_reader :frame

      def initialize
        @frame = 0
      end

      def raining? = frame < RAIN_FRAMES

      # Each tick's a frame, and any other key puts the waffle away, which is when it's over.
      def over?(key)
        @frame += 1 if key == :tick
        key != :tick
      end
    end
  end
end
