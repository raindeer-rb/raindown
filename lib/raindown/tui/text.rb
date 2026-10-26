# frozen_string_literal: true

require 'unicode/display_width'

module Raindown
  module TUI
    # Text measured in a terminal's columns, where a wide character like 界 takes two, and cut to fit them.
    module Text
      INDENT = '  '

      private

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
