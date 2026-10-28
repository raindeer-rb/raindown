# frozen_string_literal: true

require_relative 'baked_waffle'

module Raindown
  module TUI
    # The waffle after the rain, between balloons floating up, when a batch of code is refined, and the week's work is
    # done: a BakedWaffle, then a blank line, then what's been done. Once it's popped, syrup pours onto its butter, then
    # fills its pockets.
    module Waffle
      TEXT = [[], [['100% refined', :feelings]], [['The work is mysterious and important.', :feelings]]].freeze
      # The row the waffle pops out from, its butter's on the middle ridge, and the frames each row more above and below
      # it takes, half a second at the Screen's 20 frames a second while it celebrates.
      BUTTER_ROW = BakedWaffle::POCKETS * BakedWaffle::ROW_LINES / 2
      POP_FRAMES = 10
      # The frames until it's all popped, and then the frames each pocket takes to fill with syrup, once it's poured.
      POPPED_FRAMES = POP_FRAMES * (BakedWaffle.down + TEXT.length - 1 - BUTTER_ROW)
      FILL_FRAMES = 10

      private

      # The waffle over the lines, as it pops, by the frames since the rain stopped: the butter's row first, then a row
      # more above and below it every POP_FRAMES, then its lines of text, and then the syrup.
      def waffle(lines, frame)
        top = waffle_top
        [*BakedWaffle.rows(syrup: filled(frame, top)), *TEXT].each_with_index do |parts, row|
          next unless popped?(parts, row, frame) && lines[top + row]

          lines[top + row] = over(lines[top + row], parts)
        end
        pour(lines, frame, top)
      end

      def waffle_top = [(height - BakedWaffle.down - TEXT.length) / 2, 0].max

      def popped?(parts, row, frame) = parts.any? && (row - BUTTER_ROW).abs <= frame / POP_FRAMES

      # The syrup's stream, falling a line a frame from the top onto the butter, once it's all popped, until every
      # pocket's filled.
      def pour(lines, frame, top)
        poured = frame - POPPED_FRAMES
        return lines if poured.negative? || filled(frame, top) >= BakedWaffle::POCKETS**2

        [poured, stream(top)].min.times { lines[it] = overlay_segments(lines[it], [segment('│', :syrup, width: 1)], column: stream_column) }
        lines
      end

      # The lines from the top down to the butter, and the column of the waffle's middle, which the syrup falls down.
      def stream(top) = top + BUTTER_ROW - 1
      def stream_column = ((width - BakedWaffle.across - 2) / 2) + 1 + (BakedWaffle.across / 2)

      # The pockets filled with syrup by the frame, one every FILL_FRAMES once the stream's reached the butter.
      def filled(frame, top) = [(frame - POPPED_FRAMES - stream(top)) / FILL_FRAMES, 0].max

      # The parts over the middle of the line, with a space either side, so they're clear of the balloons behind them.
      def over(line, parts)
        segments = [[' ', :blank], *parts, [' ', :blank]].map { |text, style| segment(text, style, width: display_width(text)) }
        overlay_segments(line, segments, column: [(width - segments.sum { display_width(it.text) }) / 2, 0].max)
      end
    end
  end
end
