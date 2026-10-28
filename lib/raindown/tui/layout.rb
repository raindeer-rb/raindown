# frozen_string_literal: true

require_relative 'events'
require_relative 'text'
require_relative 'title'
require_relative 'menu_overlay'
require_relative 'search_overlay'

module Raindown
  module TUI
    # The screen as lines of styled segments, worked out from a Navigator with no terminal, so the Screen only paints them.
    # A Layout and its Renderers are the display code, made again for each draw: they lay out and render what the
    # Navigator and its views hold. The Layout draws the title, the status and the buttons around two panes, nav and main,
    # and a Renderer draws what's in each pane: the nav's ListRenderer, and the open view's renderer, an OutlineRenderer,
    # DashboardRenderer or EndpointRenderer, which gives the buttons and page too:
    #    ┌─ Layout ──────────────────────────────────────────────────┐
    #    │  Raindown  ~/docs › guides/setup.md                       │
    #    │ ┌─ nav pane ──────┐ ┌─ main pane ───────────────────────┐ │
    #    │ │ Dashboard       ▏ # Setup                             │ │
    #    │ │ ▾ guides/       ▏   toc: [+3]                         │ │
    #    │ │   setup.md      ▏   ## Install                        │ │
    #    │ └─ ListRenderer ──┘ └─ view.renderer ───────────────────┘ │
    #    │  Opened guides/setup.md                                   │
    #    │  Tab Pane  Enter Open  X Run  E dit  W rite back  Q uit   │
    #    └───────────────────────────────────────────────────────────┘
    # Each line is exactly the width, in display columns. A segment with an event is clicked to send it.
    class Layout
      include Text
      include Title

      NAV_WIDTH = (16..32)
      # The line between the nav and main panes, at its column's left edge, unlike │ in the middle,
      # so a highlighted file's row runs up to it.
      DIVIDER = '▏'
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

        overlaid([title, *panes, status, button_bar])
      end

      # A third of the width, within NAV_WIDTH, and never more than half of a narrow screen.
      def nav_width
        [(width / 3).clamp(NAV_WIDTH), width / 2].min
      end

      private

      # The project menu or the search, drawn over the lines while it's open.
      def overlaid(lines)
        return MenuOverlay.new(navigator, width:, column: display_width(name)).apply(lines) if navigator.menu
        return SearchOverlay.new(navigator, width:).apply(lines) if navigator.searching?

        lines
      end

      def body_height = height - CHROME_HEIGHT

      # Below a blank line for spacing, the nav pane beside the main pane, each drawn by the renderer of what's in it.
      def panes
        nav = renderer_in(:nav, nav_width).lines
        main = view_renderer.lines

        [spacer, *Array.new(body_height - 1) { |index| [*nav[index], divider(main[index]), *main[index]] }]
      end

      # A line above the panes, for spacing, blank but for what the main pane's renderer puts in its side of it.
      def spacer = [segment('', :blank, width: nav_width), divider([]), *view_renderer.spacer]

      # The divider is on the background of the outline's row beside it, when that's highlighted, so they meet.
      def divider(main_line)
        style = { selected: :selected_divider, cursor: :cursor_divider }.fetch(main_line.first&.style, :divider)
        segment(DIVIDER, style, width: 1)
      end

      def view_renderer
        @view_renderer ||= renderer_in(:main, width - nav_width - 1)
      end

      def renderer_in(pane, width)
        navigator.content(pane).renderer.new(navigator:, pane:, width:, height: body_height - 1)
      end

      def status
        kind, message = navigator.status
        [segment(" #{message}", kind)]
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

        view_renderer.buttons.each do |key, label, event|
          key, label = shown(key, label)
          pair = [Segment.new(text: " #{key} ", style: :key, event:), Segment.new(text: "#{label} ", style: :bar, event:)]
          pair_width = display_width(pair.map(&:text).join)
          break if used + pair_width > width

          segments.concat(pair)
          used += pair_width
        end

        [*segments, segment('', :bar, width: width - used)]
      end
    end
  end
end

require_relative 'renderers/list_renderer'
require_relative 'renderers/outline_renderer'
require_relative 'renderers/dashboard_renderer'
require_relative 'renderers/endpoint_renderer'
require_relative 'feelings/feelings_renderer'
