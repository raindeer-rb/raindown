# frozen_string_literal: true

require_relative '../highlighter'

module Raindown
  module TUI
    # Code feelings' box below the grid: the selected method's code, highlighted, its first lines or, expanded, all that
    # fit, then why it felt that way while that's typed, below a line:
    #    ╭─ lib/text.rb:62 · Text#segments_between ──────────── changed 6× ─╮
    #    │ def segments_between(line, from, to)                              │
    #    │ … 12 more lines                                                   │
    #    ├───────────────────────────────────────────────────────────────────┤
    #    │ Why DREAD? > column maths, a character at a time▏                 │
    #    ╰───────────────────────────────────────────────────────────────────╯
    module CodeBox
      # The most of a method's code that shows, until it's expanded, and the rows the grid keeps when it is.
      CODE_LINES = 8
      MIN_GRID_ROWS = 2
      # The box's top and bottom, and the line of how many more lines there are.
      BOX_LINES = 3

      private

      # The selected method's code in a box, then why it felt that way while that's typed, below a line.
      def code_box
        notes = []
        notes = note_lines if view.typing?
        [box_top(view.selected), *code_lines(height - FeelingsRenderer::BIN_LINES - BOX_LINES - MIN_GRID_ROWS - notes.length), *notes,
         box_edge('╰', '╯')]
      end

      # The method's first lines, or all that fit in the room when it's expanded, highlighted, then how many more
      # there are, clicked to show them, or a line to show fewer again.
      def code_lines(room)
        method = view.selected
        shown = CODE_LINES
        shown = [room, CODE_LINES].max if view.expanded
        code = Highlighter.lines(dedented(method.lines.first(shown)), filename: method.path).map { boxed(it) }
        return code if method.lines.length <= CODE_LINES

        [*code, more_line(method.lines.length - shown)]
      end

      def more_line(hidden)
        text = "… #{hidden} more lines"
        text = '… 1 more line' if hidden == 1
        text = "▴ Fewer lines#{" · #{hidden} more don't fit" if hidden.positive?}" if view.expanded
        boxed([[text, :body]], event: Click.new(pane:, index: view.cursor, action: :expand))
      end

      # Why it felt that way, as it's typed, below a line, in as many lines as it takes.
      def note_lines = [box_edge('├', '┤'), *hanging("Why #{view.noting.upcase}? > ", "#{view.note}▏").map { boxed([[it, :menu]]) }]

      # The text after the lead, wrapped to fit the box, with the lines after the first lined up under the text.
      def hanging(lead, text)
        indent = ' ' * display_width(lead)
        lines = wrap(text, width - 6 - indent.length)
        [lead, *Array.new(lines.length - 1, indent)].zip(lines).map(&:join)
      end

      # Where the method is, its name, and how many commits changed its file.
      def box_top(method) = box_edge("╭─ #{where(method)} · #{method.label} ", " changed #{method.changes}× ─╮")

      # The lines without the indent they share, like a method's in its class.
      def dedented(lines)
        indent = lines.reject { it.strip.empty? }.map { it[/\A */].length }.min.to_i
        lines.map { it[indent..].to_s }
      end

      def where(method) = "#{navigator.relative(method.path)}:#{method.line}"

      # A line of the box, a column in from each side of the pane, of [text, style] parts, like highlighted code's.
      def boxed(parts, event: nil)
        padded([segment(' │ ', :border, width: 3), *code_segments(parts, width - 6, event:), segment(' │', :border, width: 2)])
      end

      # The box's top or bottom, with the left text cut short, rather than the corner, when there isn't room.
      def box_edge(left, right)
        room = width - 2 - display_width(right)
        left = "#{fit(left, room - 1)} " if display_width(left) > room
        fill = [room - display_width(left), 0].max
        padded([segment(" #{left}#{'─' * fill}#{right}", :border, width: width - 1)])
      end
    end
  end
end
