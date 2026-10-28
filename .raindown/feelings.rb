# frozen_string_literal: true

require 'csv'

# How the code felt, sorted in raindown tui's Code feelings, charting how many methods felt each way:
#   <{ Feelings: width=30 }>
# It's a chart: whose data is counted from .raindown/feelings.csv, so it takes the same props, like width:.
class Feelings < Raindown::Chart
  TEMPERS = %w[woe frolic dread malice numb].freeze

  def initialize(width: 30, **props)
    super(width:, **props)
  end

  def points(metadata: Raindown::NoMetadata)
    root = metadata.respond_to?(:root) ? metadata.root : Dir.pwd
    csv = File.join(root, '.raindown', 'feelings.csv')
    return [] unless File.exist?(csv)

    tally = CSV.read(csv, headers: true).map { it['temper'] }.tally
    Points.new(root:).from(TEMPERS.to_h { [it, tally.fetch(it, 0)] })
  end
end
