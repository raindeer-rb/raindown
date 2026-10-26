# frozen_string_literal: true

require 'unicode/display_width'

module Raindown
  module TUI
    # A chart on the dashboard, drawn from its data by its project's Worker: a title of its file, from its project,
    # and the heading above it, then its directive, then the chart, each line with its Layout style,
    # in a border with rounded corners. It's as wide as the chart, so the title and directive are cut to fit it:
    #    ╭───────────────────────────────────────╮
    #    │ markdown.md › Charts                  │
    #    │ chart: 'data/downloads.csv' width: 30 │
    #    │ Jun  ██████▊                   640    │
    #    ╰───────────────────────────────────────╯
    class Card < Data.define(:project, :path, :line, :heading, :directive, :chart)
      # The border's columns either side of a card's lines, "│ " and " │", and its lines above and below them.
      BORDER_WIDTH = 4
      BORDER_HEIGHT = 2

      def title = [path.delete_prefix(File.join(project, '')), heading].compact.join(' › ')

      def lines = parts.map(&:first)

      # Each line, with its style.
      def parts = [[title, :heading], [directive, :directive], *chart.map { [it, :chart] }]

      # As wide as its chart.
      def width = chart.map { Unicode::DisplayWidth.of(it) }.max || 0

      def height = lines.length

      # With its border, within a range of widths, like a pane's.
      def box_width(within: nil) = within ? (width + BORDER_WIDTH).clamp(within) : width + BORDER_WIDTH
      def box_height = height + BORDER_HEIGHT

      # A line of the card in its border, as [text, style, width] parts, for a card the box width wide.
      # The border's top is line 0, and below its bottom, the lines are blank, for a card shorter than its row.
      # The title's style is title_style, like when the card's selected.
      def format_line(line, box_width:, title_style: :heading)
        width = [box_width - BORDER_WIDTH, 0].max
        return [border(width, '╭', '╮')] if line.zero?
        return [border(width, '╰', '╯')] if line == height + 1
        return [['', :blank, width + BORDER_WIDTH]] if line > height + 1

        text, style = parts[line - 1]
        [['│ ', :border, 2], [text, style == :heading ? title_style : style, width], [' │', :border, 2]]
      end

      private

      def border(width, left, right)
        ["#{left}#{'─' * (width + 2)}#{right}", :border, width + BORDER_WIDTH]
      end
    end
  end
end
