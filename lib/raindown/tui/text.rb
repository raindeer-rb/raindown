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

      # A line of highlighted code's [text, style] parts as segments, cut or padded to the width.
      def code_segments(parts, width, event: nil)
        segments = segments_between(parts.map { |text, style| Segment.new(text: printable(text), style:, event:) }, 0, width)
        [*segments, segment('', :code, width: width - segments.sum { display_width(it.text) }, event:)]
      end

      # The text in lines that fit the width, broken at spaces where it can, and inside a word too long for a line.
      def wrap(text, width)
        return [text] unless width.positive?

        text.scan(/\S+|\s+/).each_with_object([+'']) do |part, lines|
          next lines.last << part if display_width(lines.last + part) <= width
          next lines << +'' if part.strip.empty?

          lines << +'' unless lines.last.empty?
          break_word(part, width, lines)
        end
      end

      # Adds a word too long for a line to the lines, a character at a time, starting a new line when one's full.
      def break_word(word, width, lines)
        word.each_char do |char|
          lines << +'' if display_width(lines.last + char) > width
          lines.last << char
        end
      end

      # The line's segments, with others drawn over its columns from the column on, like a box over the screen.
      def overlay_segments(line, segments, column:)
        width = segments.sum { display_width(it.text) }
        [*segments_between(line, 0, column), *segments, *segments_between(line, column + width, Float::INFINITY)]
      end

      # The parts of the line's segments between two columns, where a wide character cut in two leaves spaces.
      def segments_between(line, from, to)
        column = 0
        line.filter_map do |segment|
          text = segment.text.each_char.map do |char|
            start = column
            column += display_width(char)
            overlap = [column, to].min - [start, from].max
            overlap == display_width(char) ? char : ' ' * [overlap, 0].max
          end.join
          segment.with(text:) unless text.empty?
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
