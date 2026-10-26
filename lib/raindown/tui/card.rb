# frozen_string_literal: true

require 'unicode/display_width'

module Raindown
  module TUI
    # A chart on the dashboard, drawn from its data by its project's Worker: a title of its file, from its project,
    # and the heading above it, then its directive, then the chart, each line with its Layout style.
    # It's as wide as the chart, so the title and directive are cut to fit it:
    #    markdown.md › Charts
    #    chart: 'data/downloads.csv' width: 30
    #    Jun  ██████▊                   640
    Card = Data.define(:project, :path, :line, :heading, :directive, :chart) do
      def title = [path.delete_prefix(File.join(project, '')), heading].compact.join(' › ')

      def lines = parts.map(&:first)

      # Each line, with its style.
      def parts = [[title, :heading], [directive, :directive], *chart.map { [it, :chart] }]

      # As wide as its chart, within a range of widths, like a pane's.
      def width(within: nil)
        width = chart.map { Unicode::DisplayWidth.of(it) }.max || 0
        within ? width.clamp(within) : width
      end

      def height = lines.length
    end
  end
end
