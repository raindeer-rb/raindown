# frozen_string_literal: true

require_relative 'events'
require_relative 'text'

module Raindown
  module TUI
    # The search, drawn over the screen's lines in a box below the title: what's typed, then the places that match it,
    # each with where it is, and the selected one highlighted:
    #    ┌─ Teleport ───────────────────────────────┐
    #    │ / stp▏                                   │
    #    │ ## Setup               guides/setup.md:3 │
    #    │ ## Steps                     notes.md:12 │
    #    └──────────────────────────────────────────┘
    # Each place is clicked to open it.
    class SearchOverlay
      include Text

      # The widest the box is, with its border.
      MAX_WIDTH = 72

      def initialize(navigator, width:)
        @navigator = navigator
        @box_width = [width - 4, MAX_WIDTH].min
        @column = (width - @box_width) / 2
      end

      # The lines with the box drawn over them, from the line below the title.
      def apply(lines)
        box.each_with_index do |segments, offset|
          row = offset + 1
          lines[row] = overlay_segments(lines[row], segments, column: @column) if lines[row]
        end
        lines
      end

      private

      # The columns inside the border, "│ " and " │".
      def inner = @box_width - 4

      def box
        [edge('┌─ Teleport ', '┐'), boxed(segment("/ #{@navigator.query}▏", :menu, width: inner)), *results, edge('└', '┘')]
      end

      def results
        matches = @navigator.matches
        return [boxed(segment('No matches', :info, width: inner))] if matches.empty?

        matches.each_with_index.map { |place, index| place_line(place, index) }
      end

      # The place's text, then where it is, on the right, both highlighted when it's selected.
      def place_line(place, index)
        text_style = :menu
        where_style = :body
        text_style = where_style = :selected if @navigator.match == index
        event = Click.new(pane: :search, index:, action: :enter)
        where = " #{place.where}"
        where_width = [display_width(where), inner / 2].min

        boxed(segment(place.text, text_style, width: inner - where_width, event:),
              segment(where, where_style, width: where_width, event:))
      end

      def boxed(*segments) = [segment('│ ', :border, width: 2), *segments, segment(' │', :border, width: 2)]

      def edge(left, right)
        [segment("#{left}#{'─' * (@box_width - display_width(left) - 1)}#{right}", :border, width: @box_width)]
      end
    end
  end
end
