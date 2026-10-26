# frozen_string_literal: true

require_relative 'layout'

module Raindown
  module TUI
    # The dashboard, right of the files: a card for each of the projects' charts, as wide as its chart,
    # with as many in a row as fit. With more than one project, each project's charts are under its path.
    # A card has its file and heading, and its directive, both cut to the chart's width, then the chart:
    #    raindown.rd › Charts                 raindown.rd › Commits
    #    chart: 'data/downloads.csv'          chart: 'data/commits.csv' minus: 'deleted'
    #    Jun  ██████▊              640        c2f98fc  -18  █│███▊      +96
    #    Jul  █████████████      1,240        b1a573a   -0   │▏          +1
    # Its lines are the pane's width and height, which the Layout puts beside the files.
    class DashboardPane < Layout
      # Columns between the cards, and the narrowest a card is.
      GAP = 3
      MIN_CARD_WIDTH = 24

      def lines
        cards = dashboard.cards
        return blank(height, " No charts in #{File.basename(navigator.root)} yet, like <{ chart: '3 5 2 8' }>") if cards.empty?

        rows = packed(cards)
        dashboard.rows = rows
        grid(rows, cards)
      end

      private

      def dashboard = navigator.dashboard

      # The cards' indexes in rows, with as many of a project's cards in a row as fit across, after a column of margin.
      # Each project's cards start a row, under the project's heading when there's more than one.
      def packed(cards)
        groups = cards.each_index.chunk_while { |a, b| cards[a].project == cards[b].project }.to_a
        @headings = {}

        groups.each_with_object([]) do |indexes, rows|
          @headings[rows.length] = cards[indexes.first].project if groups.length > 1
          rows.concat(group_rows(cards, indexes))
        end
      end

      def group_rows(cards, indexes)
        rows = [[]]
        used = 1

        indexes.each do |index|
          card_width = cards[index].width(within: card_widths) + (rows.last.empty? ? 0 : GAP)
          if used + card_width > width && rows.last.any?
            rows << []
            used = 1
            card_width -= GAP
          end
          rows.last << index
          used += card_width
        end

        rows
      end

      # The widths a card can be: no narrower than MIN_CARD_WIDTH, when there's room, and no wider than the pane.
      def card_widths = [MIN_CARD_WIDTH, width - 1].min..(width - 1)

      # The rows of cards from the first that's scrolled to, each card's lines side by side, with a line between rows.
      def grid(rows, cards)
        heights = rows.each_with_index.map { |row, index| row_height(row, cards) + (@headings.key?(index) ? 1 : 0) }
        first = dashboard.scroll(heights, height)
        lines = (first...rows.length).flat_map { |index| row_lines(rows[index], cards, heading: @headings[index]) }

        (lines + blank(height)).first(height)
      end

      # The tallest card's lines, and one line below it.
      def row_height(row, cards)
        row.map { cards[it].height }.max + 1
      end

      def row_line(row, cards, line)
        segments = [segment('', :blank, width: 1)]

        row.each_with_index do |index, column|
          segments << segment('', :blank, width: GAP) unless column.zero?
          segments << card_line(cards[index], index, line)
        end

        [*segments, segment('', :blank, width: width - segments.sum { display_width(it.text) })]
      end

      # A card opens chart source when it's clicked, like Enter.
      # The selected card's title is highlighted, like a selected row.
      def card_line(card, index, line)
        text, style = card.parts[line] || ['', :blank]
        style = row_style(:dashboard, nil, true) if style == :heading && dashboard.cursor == index

        segment(text, style, width: card.width(within: card_widths), event: Click.new(pane: :dashboard, index:, action: :enter))
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
