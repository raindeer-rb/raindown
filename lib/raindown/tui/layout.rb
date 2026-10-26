# frozen_string_literal: true

require_relative 'text'
require_relative 'title'

module Raindown
  module TUI
    # The screen as lines of styled segments, worked out from a Navigator with no terminal, so the Screen only paints them.
    # A title, the files pane beside the outline, a status line and a bar of buttons:
    #    🌧️ Raindown  ~/docs › guides/setup.md
    #    📊 Dashboard    │ # Setup
    #    ▾ guides/       │   toc: [+3]
    #      setup.md      │   ## Install
    #    Opened guides/setup.md
    #    Tab Pane  Enter Open  x Run  e Edit  w Write back  d Charts  r Reload  q Quit
    # Each line is exactly the width, in display columns. A segment with an event is clicked to send it.
    # With the Dashboard chosen in the files, a DashboardPane of the project's charts is in place of the outline.
    class Layout
      include Text
      include Title

      Segment = Data.define(:text, :style, :event)

      BUTTONS = [['Tab', 'Pane', :tab], ['Enter', 'Open', :enter], ['x', 'Run', :execute], ['e', 'Edit', :edit],
                 ['w', 'Write back', :write_back], ['r', 'Reload', :reload], ['q', 'Quit', :quit]].freeze
      DASHBOARD_BUTTONS = [['Tab', 'Pane', :tab], ['Enter', 'Open', :enter], ['e', 'Edit', :edit], ['r', 'Reload', :reload],
                           ['q', 'Quit', :quit]].freeze
      PROJECTS_BUTTON = ['p', 'Projects', :projects].freeze
      FILES_WIDTH = (16..32)
      INDENT = Text::INDENT
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

        lines = [title, *body, status, button_bar]
        return lines unless navigator.menu

        require_relative 'menu_overlay'
        MenuOverlay.new(navigator, width:, column: display_width(name), from_home: method(:from_home)).apply(lines)
      end

      # A third of the width, within FILES_WIDTH, and never more than half of a narrow screen.
      def files_width
        [(width / 3).clamp(FILES_WIDTH), width / 2].min
      end

      private

      def body = panes

      def dashboard? = navigator.view == :dashboard

      def body_height = height - CHROME_HEIGHT

      def panes
        pane_height = body_height
        files = navigator.visible(:files, pane_height)
        main = main_pane(width - files_width - 1, pane_height)

        Array.new(pane_height) do |index|
          [*cell(:files, *files, index, files_width), Segment.new(text: '│', style: :border, event: nil), *main[index]]
        end
      end

      # The outline's lines, or the dashboard's.
      def main_pane(pane_width, pane_height)
        if dashboard?
          require_relative 'dashboard_pane'
          return DashboardPane.new(navigator, width: pane_width, height: pane_height).lines
        end

        outline = navigator.visible(:outline, pane_height)
        Array.new(pane_height) { |index| cell(:outline, *outline, index, pane_width) }
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

      # The dashboard's buttons have room for the project menu's, when there's more than one project.
      def buttons
        return BUTTONS unless dashboard?

        navigator.projects? ? DASHBOARD_BUTTONS.dup.insert(3, PROJECTS_BUTTON) : DASHBOARD_BUTTONS
      end

      # As many buttons as fit, each clicked by its key or its label.
      def button_bar
        segments = []
        used = 0

        buttons.each do |key, label, event|
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
    end
  end
end
