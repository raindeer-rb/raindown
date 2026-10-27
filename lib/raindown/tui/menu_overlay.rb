# frozen_string_literal: true

require_relative 'text'

module Raindown
  module TUI
    # The project menu, drawn over the screen's lines in a box below the header's path:
    #    🌧 Raindown  ~/dev ▾ › Dashboard
    #                 ┌──────────────────────┐
    #                 │ All projects       ✓ │
    #                 │ ~/dev/raindown       │
    #                 └──────────────────────┘
    # Each item is clicked to choose it.
    class MenuOverlay
      include Text

      def initialize(navigator, width:, column:)
        @navigator = navigator
        @width = width
        @column = column
      end

      # The lines with the box drawn over them, from the line below the header.
      def apply(lines)
        box.each_with_index.map { |segments, offset| [offset + 1, segments] }.each do |row, segments|
          lines[row] = overlay_segments(lines[row], segments, column: @column) if lines[row]
        end
        lines
      end

      private

      def items
        @navigator.menu_items.map { |project| project ? from_home(project) : 'All projects' }
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
        [segment('│ ', :border), segment(text, style, Click.new(pane: :menu, index:, action: :enter)), segment(' │', :border)]
      end

      def segment(text, style, event = nil)
        Text::Segment.new(text:, style:, event:)
      end
    end
  end
end
