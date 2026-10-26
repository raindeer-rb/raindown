# frozen_string_literal: true

require 'raindown/tui/dashboard'
require 'raindown/tui/workers'
require 'fileutils'
require 'tmpdir'

# A project's own chart, drawn its own way, which the dashboard shows as well.
class SpecSales < Raindown::Chart
  def initialize(**) = super('3 1 2', **)
end

RSpec.describe Raindown::TUI::Dashboard do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      FileUtils.mkdir_p(File.join(@root, '.raindown'))
      example.run
    end
  end

  def write(name, content)
    File.join(@root, name).tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end

  let(:dashboard) { described_class.new(root: @root, workers: Raindown::TUI::Workers.new(root: @root)) }

  before do
    write('data/sales.csv', "month,sales\nJan,4\nFeb,8\n")
    write('notes.md', "# Notes\n\n<{ :toc }>\n\n## Sales\n\n<{ chart: 'data/sales.csv' width: 10 }>\n<{ :chart }>\n")
    write('guides/stats.rd', "# Stats\n\nchart: '1 2 3'\n\nSpecSales:\n")
  end

  it "finds every chart in the project's files, with its file, line, heading and directive, including a project's own" do
    charts = dashboard.charts.map { [File.basename(it.path), it.line, it.heading, it.directive] }

    expect(charts).to eq([['stats.rd', 3, 'Stats', "chart: '1 2 3'"], ['stats.rd', 5, 'Stats', 'SpecSales:'],
                          ['notes.md', 7, 'Sales', "chart: 'data/sales.csv' width: 10"]])
  end

  it 'draws each chart from its data, as it would be written back' do
    expect(dashboard.cards.map(&:lines)).to eq([['▁▅█'], ['█▁▅'], ['Jan  █████      4', 'Feb  ██████████ 8']])
  end

  it "draws the charts again when they're loaded, following changes to their data" do
    write('data/sales.csv', "month,sales\nJan,9\n")
    dashboard.load

    expect(dashboard.cards.last.lines.length).to eq(1)
  end

  it "shows a chart's error in its card, and the files it couldn't read" do
    write('broken.md', "<{ chart: '1 2' }>\n")
    write('missing.md', "<{ chart: 'data/missing.csv' }>\n<{ :chart }>\n")

    expect(dashboard.errors).to eq(['broken.md: <{ chart: }> on line 1 needs <{ :chart }>'])
    expect(dashboard.cards.find { it.path.end_with?('missing.md') }.lines.first).to start_with("Can't chart")
  end

  describe '#handle' do
    before { dashboard.rows = [[0, 1], [2]] }

    it 'moves along the cards, and to the row above or below' do
      dashboard.handle(:right)
      expect(dashboard.cursor).to eq(1)

      dashboard.handle(:down)
      expect(dashboard.cursor).to eq(2)

      dashboard.handle(:up)
      expect(dashboard.cursor).to eq(0)
    end

    it "opens or edits the selected chart's file at its directive" do
      dashboard.handle([:press, :dashboard, 2, :enter])

      expect(dashboard.handle(:enter)).to eq([:open, File.join(@root, 'notes.md'), 7])
      expect(dashboard.handle(:edit)).to eq([:edit, File.join(@root, 'notes.md'), 7])
      expect(dashboard.handle([:press, :dashboard, 0, :enter])).to eq([:open, File.join(@root, 'guides', 'stats.rd'), 3])
    end
  end

  describe '#scroll' do
    it 'scrolls down to the cursor, and back up' do
      dashboard.rows = [[0], [1], [2]]
      2.times { dashboard.handle(:down) }

      expect(dashboard.scroll([5, 5, 5], 8)).to eq(2)

      dashboard.handle(:up)
      expect(dashboard.scroll([5, 5, 5], 8)).to eq(1)
    end
  end
end
