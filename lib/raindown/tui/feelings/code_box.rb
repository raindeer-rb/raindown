# frozen_string_literal: true

require_relative '../highlighter'

module Raindown
  module TUI
    # Code feelings' box below the grid: the code of the method the mouse is over, or else the selected one, highlighted,
    # its first lines or, expanded, all that fit, then why it felt that way while that's typed, below a line:
    #    ╭─ lib/text.rb:62 · Text#segments_between ──────────── changed 6× ─╮
    #    │ def segments_between(line, from, to)                              │
    #    │ [12 more lines]                                                   │
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

      # The code of the method the mouse is over, or else the selected one, in a box, then why it felt that way while that's
      # typed, below a line.
      def code_box
        notes = []
        notes = note_lines if view.typing?
        [box_top(hovered_method || view.selected), *shown_code_lines(notes.length), *notes, box_edge('╰', '╯')]
      end

      # The selected method's code, or the hovered one's first lines in as many lines as the selected one's take, so the
      # grid above stays still.
      def shown_code_lines(notes)
        code = code_lines(view.selected, code_room(notes), view.expanded)
        return code unless hovered_method

        lines = code_lines(hovered_method, 0, false).first(code.length)
        [*lines, *Array.new(code.length - lines.length) { boxed([]) }]
      end

      # The lines the code can take when it's expanded, leaving the grid its rows.
      def code_room(notes) = height - Bins::BIN_LINES - BOX_LINES - MIN_GRID_ROWS - notes

      # The method the mouse is over in the grid, unless it's the selected one, or a note's being typed about that.
      def hovered_method
        hovered = navigator.hovered
        return unless hovered.is_a?(Click) && hovered.pane == pane && hovered.action == :focus
        return if hovered.index == view.cursor || view.typing?

        view.code_methods[hovered.index]
      end

      # The method's first lines, or all that fit in the room when it's expanded, highlighted and wrapped to fit the box,
      # then how many more there are, clicked to show them, or a line to show fewer again.
      def code_lines(method, room, expanded)
        shown = CODE_LINES
        shown = [room, CODE_LINES].max if expanded
        lines = highlighted_code(method).map { wrapped(it) }
        fitting = lines.take_while { (shown -= it.length) >= 0 }
        code = fitting.flatten(1).map { boxed(it) }
        return code if lines.sum(&:length) <= CODE_LINES

        [*code, more_line(lines.length - fitting.length, expanded)]
      end

      def highlighted_code(method)
        view.highlighted(method) { Highlighter.lines(dedented(method.lines), filename: method.path) }
      end

      # The highlighted line's [text, style] parts in as many lines as it takes to fit the box, like a note's, those
      # after the first carrying on after an ellipsis.
      def wrapped(parts)
        room = width - 6
        lead = [carried_lead(parts, room), :feelings]
        rest = room - display_width(lead[0])
        return [parts] if rest < 1

        first, *others = line_breaks(parts.map { printable(it[0]) }.join, room, rest).each_cons(2).map { parts_between(parts, *it) }
        [first, *others.map { [lead, *it] }]
      end

      # Where the text breaks into lines, the first fitting the room and the others the rest.
      def line_breaks(text, room, rest)
        breaks = [0]
        fits = room
        while text.length - breaks.last > fits
          breaks << line_break(text, breaks.last, fits)
          fits = rest
        end
        breaks << text.length
      end

      # Where a line from the column breaks: after the last space that fits, or where it's full when none does.
      def line_break(text, from, fits)
        space = text[from, fits].rindex(' ').to_i
        return from + fits unless space.positive?

        from + space + 1
      end

      # An ellipsis at the line's own indent, up to half the room, which the lines it's wrapped onto start with.
      def carried_lead(parts, room) = "#{' ' * [parts.map(&:first).join[/\A */].length, room / 2].min}… "

      # The parts' text between two columns, in their styles.
      def parts_between(parts, from, to)
        segments = parts.map { |text, style| Text::Segment.new(text: printable(text), style:, event: nil) }
        segments_between(segments, from, to).map { [it.text, it.style] }
      end

      def more_line(hidden, expanded)
        text = "[#{hidden} more lines]"
        text = '[1 more line]' if hidden == 1
        text = "[Fewer lines]#{" · #{hidden} more don't fit" if hidden.positive?}" if expanded
        boxed([[text, :button]], event: Click.new(pane:, index: view.cursor, action: :expand))
      end

      # Why it felt that way, as it's typed, below a line, in as many lines as it takes.
      def note_lines = [box_edge('├', '┤'), *hanging("Why #{view.noting.upcase}? > ", "#{view.note}▏").map { boxed([[it, :feelings]]) }]

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
        padded([segment(' │ ', :feelings, width: 3), *code_segments(parts, width - 6, event:), segment(' │', :feelings, width: 2)])
      end

      # The box's top or bottom, with the left text cut short, rather than the corner, when there isn't room.
      def box_edge(left, right)
        room = width - 2 - display_width(right)
        left = "#{fit(left, room - 1)} " if display_width(left) > room
        fill = [room - display_width(left), 0].max
        padded([segment(" #{left}#{'─' * fill}#{right}", :feelings, width: width - 1)])
      end
    end
  end
end
