# frozen_string_literal: true

require_relative 'events'
require_relative 'text'
require_relative 'title'

module Raindown
  module TUI
    # The screen as lines of styled segments, worked out from a Navigator with no terminal, so the Screen only paints them.
    # A title, the files pane beside the outline, a status line and a bar of buttons:
    #    🌧️ Raindown  ~/docs › guides/setup.md
    #    📊 Dashboard    ▏ # Setup
    #    ▾ guides/       ▏   toc: [+3]
    #      setup.md      ▏   ## Install
    #    Opened guides/setup.md
    #    Tab Pane  Enter Open  X Run  E dit  W rite back  R eload  Q uit
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
      # The line between the files and the outline or dashboard, at its column's left edge, unlike │ in the middle,
      # so a highlighted file's row runs up to it.
      DIVIDER = '▏'
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

      # Below a blank line for spacing, the files beside the outline or dashboard.
      def panes
        pane_height = body_height - 1
        files = navigator.visible(:files, pane_height)
        main = main_pane(width - files_width - 1, pane_height)

        [spacer, *Array.new(pane_height) { |index| [*cell(:files, *files, index, files_width), divider(main[index]), *main[index]] }]
      end

      # A blank line above the panes, for spacing.
      def spacer = [segment('', :blank, width: files_width), divider([]), segment('', :blank, width: width - files_width - 1)]

      # The divider is on the background of the outline's row beside it, when that's highlighted, so they meet.
      def divider(main_line)
        style = { selected: :selected_divider, cursor: :cursor_divider }.fetch(main_line.first&.style, :divider)
        segment(DIVIDER, style, width: 1)
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
        return [segment('', :blank, width: cell_width)] unless row&.selectable?

        index += offset
        selected = navigator.cursor(pane) == index
        buttons = row_buttons(row, pane:, index:, selected:, cell_width:)
        text_width = cell_width - display_width(buttons.map(&:text).join)
        text = " #{INDENT * row.depth}#{row.text}"

        [segment(text, row_style(pane, row, selected), width: text_width, event: Click.new(pane:, index:, action: :enter)), *buttons]
      end

      # The row's buttons, right of its text, unless they'd take more than half the pane.
      def row_buttons(row, pane:, index:, selected:, cell_width:)
        buttons = row.buttons.map do |label, event|
          style = selected ? :"#{row_style(pane, row, true)}_button" : :button
          Segment.new(text: " #{label}", style:, event: Click.new(pane:, index:, action: event))
        end
        display_width(buttons.map(&:text).join) > cell_width / 2 ? [] : buttons
      end

      # The cursor's row is highlighted in the pane with the focus, and dimmer in the others, like the file a chart opened.
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

      # The first letter of a label is stylized as a keyboard key like "(E)dit".
      def shown(key, label)
        return [key, label] unless key.length == 1

        [key.upcase, label.downcase.start_with?(key) ? label[1..] : label]
      end

      # As many buttons as fit, each clicked by its key or its label.
      def button_bar
        segments = []
        used = 0

        buttons.each do |key, label, event|
          key, label = shown(key, label)
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
