# frozen_string_literal: true

require 'csv'

# How healthy the code feels now, sorted in raindown tui's Code feelings, from 0 to 1: the average of its feelings'
# scores, and its label how many there are. Frolic is 1, and numb 0.5, as it's
# neither good nor bad, and the bad feelings are below it, evenly, woe the mildest at a third, then dread at a sixth,
# and malice 0:
#   <{ CodeHealth: }>
# Only the feelings count, not the memories, which are about code that's since changed or gone. CodeDebt counts the
# same scores, from how far each is from numb.
class CodeHealth < Raindown::Stat
  SCORES = { 'frolic' => 1.0, 'numb' => 0.5, 'woe' => 1.0 / 3, 'dread' => 1.0 / 6, 'malice' => 0.0 }.freeze

  # The rows of .raindown/feelings.csv or memories.csv, by name.
  def self.rows(root, name)
    csv = File.join(root, '.raindown', "#{name}.csv")
    return [] unless File.exist?(csv)

    CSV.read(csv, headers: true).map(&:to_h)
  end

  # The row's feeling's score, or nil for a temper without one.
  def self.score(row) = SCORES[row['temper']]

  # Card lines ask for the value before the label, which says how many feelings it's the average of.
  def value(metadata: Raindown::NoMetadata)
    @scores = self.class.rows(root(metadata), 'feelings').filter_map { self.class.score(it) }
    return if @scores.empty?

    @scores.sum.fdiv(@scores.length)
  end

  def label = "#{@scores.length} felt"

  # To two decimal places, like 0.42, or ? before anything's felt.
  def number(value)
    return '?' unless value

    format('%.2f', value)
  end
end
