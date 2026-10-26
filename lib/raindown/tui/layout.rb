# frozen_string_literal: true

require 'unicode/display_width'

module Raindown
  module TUI
    # The screen as lines of styled segments, worked out from a Navigator with no terminal, so the Screen only paints them.
    # A title, the files pane beside the outline, a status line and a bar of buttons:
    #    raindown  docs  guides/setup.md
    #    ▾ guides/       │ # Setup
    #      setup.md      │   toc: [+3]
    #    README.md       │   ## Install
    #    Opened guides/setup.md
    #    Tab Pane  Enter Open  x Run  e Edit  w Write back  r Reload  q Quit
    # Each line is exactly the width, in display columns. A segment with an event is clicked to send it.
    class Layout
      Segment = Data.define(:text, :style, :event)

      BUTTONS = [['Tab', 'Pane', :tab], ['Enter', 'Open', :enter], ['x', 'Run', :execute], ['e', 'Edit', :edit],
                 ['w', 'Write back', :write_back], ['r', 'Reload', :reload], ['q', 'Quit', :quit]].freeze
      FILES_WIDTH = (16..32)
      INDENT = '  '
      # The title, status and button lines.
      CHROME_HEIGHT = 3

      attr_reader :navigator, :width, :height

      def initialize(navigator, width:, height:)
        @navigator = navigator
        @width = width
        @height = height
      end

      def lines
        return [status].first(height) if height < CHROME_HEIGHT + 1

        [title, *panes, status, button_bar]
      end

      def files_width
        (width / 3).clamp(FILES_WIDTH.begin, [FILES_WIDTH.end, width / 2].min)
      end

      private

      def title
        path = navigator.path ? navigator.relative(navigator.path) : 'No Markdown files'
        [segment(" raindown  #{File.basename(navigator.root)}  #{path}", :title)]
      end

      def panes
        pane_height = height - CHROME_HEIGHT
        files = navigator.visible(:files, pane_height)
        outline = navigator.visible(:outline, pane_height)

        Array.new(pane_height) do |index|
          [*cell(:files, *files, index, files_width), Segment.new(text: '│', style: :border, event: nil),
           *cell(:outline, *outline, index, width - files_width - 1)]
        end
      end

      # A pane's row as its text, then its buttons, or blank below its last row.
      def cell(pane, rows, offset, index, cell_width)
        row = rows[index]
        return [segment('', :blank, width: cell_width)] unless row

        index += offset
        selected = navigator.cursor(pane) == index
        buttons = row_buttons(row, pane:, index:, selected:, cell_width:)
        text_width = cell_width - display_width(buttons.map(&:text).join)
        text = " #{INDENT * row.depth}#{row.text}"

        [segment(text, row_style(pane, row, selected), width: text_width, event: [:select, pane, index]), *buttons]
      end

      # The row's buttons, right of its text, unless they'd take more than half the pane.
      def row_buttons(row, pane:, index:, selected:, cell_width:)
        buttons = row.buttons.map do |label, event|
          Segment.new(text: " #{label}", style: selected ? :selected_button : :button, event: [:press, pane, index, event])
        end
        display_width(buttons.map(&:text).join) > cell_width / 2 ? [] : buttons
      end

      def row_style(pane, row, selected)
        return row.kind unless selected

        navigator.focus == pane ? :selected : :cursor
      end

      def status
        kind, message = navigator.status
        [segment(" #{message}", kind)]
      end

      # As many buttons as fit, each clicked by its key or its label.
      def button_bar
        segments = []
        used = 0

        BUTTONS.each do |key, label, event|
          pair = [Segment.new(text: " #{key} ", style: :key, event:), Segment.new(text: "#{label} ", style: :bar, event:)]
          pair_width = display_width(pair.map(&:text).join)
          break if used + pair_width > width

          segments.concat(pair)
          used += pair_width
        end

        [*segments, segment('', :bar, width: width - used)]
      end

      # Text cut or padded to the width, with a cut shown by an ellipsis.
      def segment(text, style, width: self.width, event: nil)
        Segment.new(text: fit(printable(text), width), style:, event:)
      end

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
