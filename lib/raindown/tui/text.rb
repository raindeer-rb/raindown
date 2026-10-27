# frozen_string_literal: true

require 'unicode/display_width'

module Raindown
  module TUI
    # Text measured in a terminal's columns, where a wide character like 界 takes two, cut to fit them in styled Segments.
    module Text
      Segment = Data.define(:text, :style, :event)
      INDENT = '  '

      private

      # A path from the home folder when it's in it, like ~/dev/raindown.
      def from_home(path)
        home = Dir.home
        path == home || path.start_with?(File.join(home, '')) ? path.sub(home, '~') : path
      rescue ArgumentError
        path
      end

      # The text fit to the width, as a Segment in the style.
      def segment(text, style, width: self.width, event: nil)
        Segment.new(text: fit(printable(text), width), style:, event:)
      end

      # Text cut or padded to the width, with a cut shown by an ellipsis.
      def fit(text, width)
        return '' if width <= 0
        return text + (' ' * (width - display_width(text))) if display_width(text) <= width

        cut = +''
        cut_width = 0
        text.each_char do |char|
          break if cut_width + display_width(char) > width - 1

          cut << char
          cut_width += display_width(char)
        end
        "#{cut}…#{' ' * (width - 1 - cut_width)}"
      end

      # The widths of texts side by side in a width: each as wide as it is, and the last as wide as what's left,
      # with none past the width.
      def spread(texts, width)
        texts.each_with_index.map do |text, index|
          part = index == texts.length - 1 ? width : [display_width(text), width].min
          width -= part
          part
        end
      end

      # Tabs and control characters, like in a directive's output, would move the terminal's cursor.
      def printable(text)
        text.gsub("\t", INDENT).gsub(/[[:cntrl:]]/, '')
      end

      def display_width(text)
        Unicode::DisplayWidth.of(text)
      end
    end
  end
end
