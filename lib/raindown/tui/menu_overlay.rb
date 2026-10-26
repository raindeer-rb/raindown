# frozen_string_literal: true

require_relative 'text'

module Raindown
  module TUI
    # The project menu, drawn over the screen's lines in a box below the header's path:
    #    🌧️ Raindown  ~/dev ▾ › Dashboard
    #                 ┌──────────────────────┐
    #                 │ All projects       ✓ │
    #                 │ ~/dev/raindown       │
    #                 └──────────────────────┘
    # Each item is clicked to choose it.
    class MenuOverlay
      include Text

      def initialize(navigator, width:, column:, from_home:)
        @navigator = navigator
        @width = width
        @column = column
        @from_home = from_home
      end

      # The lines with the box drawn over them, from the line below the header.
      def apply(lines)
        box.each_with_index.map { |segments, offset| [offset + 1, segments] }.each do |row, segments|
          lines[row] = splice(lines[row], segments) if lines[row]
        end
        lines
      end

      private

      def items
        @navigator.menu_items.map { |project| project ? @from_home.call(project) : 'All projects' }
      end

      def inner_width
        [items.map { display_width(it) }.max + 4, @width - @column - 3].min
      end

      def box
        top = segment("┌#{'─' * (inner_width + 2)}┐", :border)
        bottom = segment("└#{'─' * (inner_width + 2)}┘", :border)
        [[top], *items.each_with_index.map { |item, index| item_line(item, index) }, [bottom]]
      end

      def item_line(item, index)
        chosen = @navigator.menu_items[index] == @navigator.project ? '✓' : ' '
        style = @navigator.menu == index ? :selected : :menu
        text = fit("#{fit(item, inner_width - 2)} #{chosen}", inner_width)
        [segment('│ ', :border), segment(text, style, [:press, :menu, index, :enter]), segment(' │', :border)]
      end

      def segment(text, style, event = nil)
        Layout::Segment.new(text:, style:, event:)
      end

      # The line's segments, with the box's put over the columns from the box's column.
      def splice(line, segments)
        box_width = segments.sum { display_width(it.text) }
        [*cut(line, 0, @column), *segments, *cut(line, @column + box_width, Float::INFINITY)]
      end

      # The parts of the segments between two columns, where a wide character cut in two leaves spaces.
      def cut(line, from, to)
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
    end
  end
end
