# frozen_string_literal: true

module Raindown
  module TUI
    # A ListRenderer's rows, like the files and the outline, each a line of the pane's width: a row's text, after its tag,
    # like an endpoint's method, then its buttons.
    module Rows
      private

      # A row as its text, then its buttons, or blank below its last row.
      def cell(pane, rows, offset, index, cell_width)
        row = rows[index]
        return [segment('', :blank, width: cell_width)] unless row&.selectable?

        index += offset
        selected = navigator.content(pane).cursor == index
        buttons = row_buttons(row, pane:, index:, selected:, cell_width:)
        text_width = cell_width - display_width(buttons.map(&:text).join)
        parts = row_parts(row, row_style(pane, row, selected), selected)

        [*spread_segments(parts, text_width, event: Click.new(pane:, index:, action: :enter)), *buttons]
      end

      # A line's segments, then blank to the edge.
      def padded(segments) = [*segments, segment('', :blank, width: [width - segments.sum { display_width(it.text) }, 0].max)]

      # [text, style] parts side by side in the width, each a segment.
      def spread_segments(parts, width, event: nil)
        parts.zip(spread(parts.map(&:first), width)).map { |(text, style), part| segment(text, style, width: part, event:) }
      end

      # The row's text, after its tag in the tag's style, or highlighted when it's code, unless the row's selected.
      def row_parts(row, style, selected)
        lead = " #{Text::INDENT * row.depth}"
        return [[lead, style], *row.code] if row.code && !selected
        return [["#{lead}#{row.text}", style]] unless row.tag

        [["#{lead}#{row.tag.method} ", selected ? style : row.tag.style], [row.text, style]]
      end

      # The row's buttons, right of its text, unless they'd take more than half the pane.
      def row_buttons(row, pane:, index:, selected:, cell_width:)
        buttons = row.buttons.map do |label, event|
          style = selected ? :"#{row_style(pane, row, true)}_button" : :button
          segment(" #{label}", style, width: display_width(" #{label}"), event: Click.new(pane:, index:, action: event))
        end
        display_width(buttons.map(&:text).join) > cell_width / 2 ? [] : buttons
      end

      # The cursor's row is highlighted in the pane with the focus, and dimmer in the other, like the file a chart opened.
      def row_style(pane, row, selected)
        return row.kind unless selected

        navigator.focus == pane ? :selected : :cursor
      end
    end
  end
end
