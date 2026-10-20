# frozen_string_literal: true

require_relative '../node'
require_relative 'bars'
require_relative 'columns'
require_relative 'line'
require_relative 'points'
require_relative 'sparkline'

module Raindown
  # The node behind chart:, a chart in block characters of the data it's given, written into the Markdown as code:
  #   chart: 'data/downloads.csv'      chart: stats format: 'columns'      chart: '3 5 -2 8'
  # The data is a CSV, TSV, JSON or YAML file relative to the project, numbers, or a variable with either, or with
  # data of its own like a list or a hash. Labeled data draws as bars and numbers alone as a sparkline,
  # unless format: is 'bars', 'columns', 'line' or 'sparkline'. Negative values go below a line, or left of it for bars.
  # A project can draw charts its own way with a Chart node in .raindown, like "class Chart < Raindown::Chart".
  class Chart < Node
    FORMATS = { 'bars' => Bars, 'columns' => Columns, 'line' => Line, 'sparkline' => Sparkline }.freeze

    # Label and value are the columns to chart, by name or index. Width is in characters, for bars and lines,
    # and height in lines, for columns and lines.
    def initialize(data = nil, format: nil, label: nil, value: nil, width: 40, height: 8) # rubocop:disable Metrics/ParameterLists -- each is a prop
      @data = data
      @format = format
      @label = label
      @value = value
      @width = width
      @height = height
    end

    # The data is read every time, so the chart follows changes to its file.
    def replace(metadata: NoMetadata)
      points = points(metadata:)
      return '' if points.empty?

      "```\n#{draw(points).map(&:rstrip).join("\n")}\n```"
    rescue Error => e
      "Can't chart #{@data.inspect}: #{e.message}"
    end

    # Each value with its label, or nil for numbers alone.
    def points(metadata: NoMetadata)
      root = metadata.respond_to?(:root) ? metadata.root : Dir.pwd
      Points.new(label: @label, value: @value, root:).from(@data)
    end

    def draw(points)
      format = @format || (points.any?(&:first) ? 'bars' : 'sparkline')
      drawing = FORMATS[format] || raise(Error, "format: is #{FORMATS.keys.join(', ')}, not #{format.inspect}")

      drawing.new(points, width: @width, height: @height).lines
    end
  end
end
