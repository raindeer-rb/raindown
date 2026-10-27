# frozen_string_literal: true

require_relative 'renderer'

module Raindown
  module TUI
    # The dashboard, right of the files: a card for each of the projects' charts, as wide as its chart,
    # with as many in a row as fit. With more than one project, each project's charts are under its path.
    # A card has its file and heading, and its directive, both cut to the chart's width, then the chart,
    # in a border with rounded corners:
    #    ╭─────────────────────────────╮  ╭────────────────────────────────╮
    #    │ raindown.rd › Charts        │  │ raindown.rd › Commits          │
    #    │ chart: 'data/downloads.csv' │  │ chart: 'data/commits.csv' min… │
    #    │ Jun  ██████▊           640  │  │ c2f98fc  -18  █│███▊      +96  │
    #    ╰─────────────────────────────╯  ╰────────────────────────────────╯
    class DashboardRenderer < Renderer
      BUTTONS = [['Tab', 'Pane', :tab], ['Enter', 'Open', :enter], ['e', 'Edit', :edit], ['r', 'Reload', :reload],
                 ['/', 'Search', :search], ['q', 'Quit', :quit]].freeze
      PROJECTS_BUTTON = ['p', 'Projects', :projects].freeze

      # Room for the project menu's button, when there's more than one project.
      def buttons
        if navigator.projects? then BUTTONS.dup.insert(3, PROJECTS_BUTTON)
        else BUTTONS
        end
      end

      def page = 'Dashboard'

      def lines
        cards = dashboard.cards
        return blank(height, " No charts in #{File.basename(navigator.root)} yet, like <{ chart: '3 5 2 8' }>") if cards.empty?

        rows = dashboard.rows(width)
        @headings = headings(rows, cards)
        grid(rows, cards)
      end

      private

      def dashboard = navigator.dashboard

      # Each project's path above its first row of cards, by the row's index, when there's more than one project.
      def headings(rows, cards)
        firsts = rows.each_index.chunk_while { |a, b| cards[rows[a].first].project == cards[rows[b].first].project }.map(&:first)
        return {} if firsts.one?

        firsts.to_h { [it, cards[rows[it].first].project] }
      end

      # The rows of cards from the first that's scrolled to, each card's lines side by side, with a line between rows.
      def grid(rows, cards)
        heights = rows.each_with_index.map { |row, index| row_height(row, cards) + (@headings.key?(index) ? 1 : 0) }
        first = dashboard.scroll(heights, height)
        lines = (first...rows.length).flat_map { |index| row_lines(rows[index], cards, heading: @headings[index]) }

        (lines + blank(height)).first(height)
      end

      # The tallest card's lines, in its border, and one line below it.
      def row_height(row, cards)
        row.map { cards[it].box_height }.max + 1
      end

      def row_line(row, cards, line)
        segments = [segment('', :blank, width: 1)]

        row.each_with_index do |index, column|
          segments << segment('', :blank, width: DashboardView::GAP) unless column.zero?
          segments.concat(card_line(cards[index], index, line))
        end

        padded(segments)
      end

      # A card opens chart source when it's clicked, like Enter, but not the space below a card shorter than its row.
      # The selected card's title is highlighted, like a selected row.
      def card_line(card, index, line)
        title_style = dashboard.cursor == index ? row_style(pane, nil, true) : :heading
        event = Click.new(pane:, index:, action: :enter) if line < card.box_height
        box_width = card.box_width(within: dashboard.card_widths(width))
        card.format_line(line, box_width:, title_style:).map do |text, style, part_width|
          segment(text, style, width: part_width, event:)
        end
      end

      # A row of cards' lines, under its project's heading when it's the project's first row.
      def row_lines(row, cards, heading:)
        [*([heading_line(heading)] if heading), *Array.new(row_height(row, cards)) { |line| row_line(row, cards, line) }]
      end

      # A project's path from the home folder, above its charts.
      def heading_line(project)
        [segment(" #{from_home(project)}", :project)]
      end

      def blank(count, message = '')
        [[segment(message, :info)], *Array.new([count - 1, 0].max) { [segment('', :blank)] }].first(count)
      end
    end
  end
end
