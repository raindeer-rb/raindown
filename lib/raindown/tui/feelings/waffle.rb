# frozen_string_literal: true

module Raindown
  module TUI
    # The waffle after the rain with a pat of butter, when a batch of code is refined, and the week's work is done:
    #    ╔═══╦═══╦═══╦═══╦═══╗
    #    ║   ║   ║   ║   ║   ║
    #    ╠═══╬═══╬═══╬═══╬═══╣
    #    ║   ║   ║███║   ║   ║
    #    ╠═══╬═══╬═══╬═══╬═══╣
    #    ║   ║   ║   ║   ║   ║
    #    ╚═══╩═══╩═══╩═══╩═══╝
    module Waffle
      EDGE = :code_number
      BUTTER = :button
      WAFFLE = [
        [['╔═══╦═══╦═══╦═══╦═══╗', EDGE]],
        [['║   ║   ║   ║   ║   ║', EDGE]],
        [['╠═══╬═══╬═══╬═══╬═══╣', EDGE]],
        [['║   ║   ║', EDGE], ['███', BUTTER], ['║   ║   ║', EDGE]],
        [['╠═══╬═══╬═══╬═══╬═══╣', EDGE]],
        [['║   ║   ║   ║   ║   ║', EDGE]],
        [['╚═══╩═══╩═══╩═══╩═══╝', EDGE]],
        [['100% refined', :feelings]],
        [['The work is mysterious and important.', :feelings]]
      ].freeze

      private

      def waffle
        top = [(height - WAFFLE.length) / 2, 0].max
        lines = [*Array.new(top, []), *WAFFLE, *Array.new(height, [])].first(height)
        lines.map { centred(it) }
      end

      # The parts in the middle of the width.
      def centred(parts)
        left = [(width - parts.sum { display_width(it[0]) }) / 2, 0].max
        padded([segment('', :blank, width: left), *parts.map { |text, style| segment(text, style, width: display_width(text)) }])
      end
    end
  end
end
