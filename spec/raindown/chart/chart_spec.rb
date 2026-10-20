# frozen_string_literal: true

require 'raindown'
require 'raindown/node_injector'
require 'tmpdir'

RSpec.describe Raindown::Chart do
  def rewrite(content, path: 'notes.rd', metadata: Raindown::NoMetadata)
    Raindown::NodeInjector.rewrite(content:, path:, metadata:)
  end

  def chart(data, **props)
    described_class.new(data, **props).replace.delete_prefix("```\n").delete_suffix("\n```")
  end

  describe 'data' do
    around do |example|
      Dir.mktmpdir do |root|
        @root = root
        example.run
      end
    end

    let(:metadata) { Struct.new(:root).new(@root) }

    def file(name, content)
      File.write(File.join(@root, name), content)
    end

    it 'reads a CSV file relative to the project, labeled by its first column' do
      file('downloads.csv', "month,downloads\nJan,1240\nFeb,620\n")

      expect(rewrite("chart: 'downloads.csv' width: 4\n", metadata:))
        .to eq("chart: 'downloads.csv' width: 4\n```\nJan  ████ 1,240\nFeb  ██     620\n```\n")
    end

    it 'reads every chart in a file, not only the first' do
      file('a.csv', "1\n2\n")

      expect(rewrite("chart: 'a.csv'\n\nchart: 'a.csv' format: 'bars' width: 2\n", metadata:)).not_to include("Can't")
    end

    it 'reads CSV files without a header, TSV, JSON and YAML' do
      file('a.csv', "a,1\nb,2\n")
      file('a.tsv', "name\tcount\na\t1\nb\t2\n")
      file('a.json', '[{"name": "a", "count": 1}, {"name": "b", "count": 2}]')
      file('a.yml', "a: 1\nb: 2\n")

      %w[a.csv a.tsv a.json a.yml].each do |name|
        expect(described_class.new(name).points(metadata:)).to eq([['a', 1], ['b', 2]])
      end
    end

    it 'charts the columns its label and value props name' do
      file('a.csv', "year,visits,sales\n2024,10,3\n2025,20,4\n")

      expect(described_class.new('a.csv', value: 'sales').points(metadata:)).to eq([['2024', 3], ['2025', 4]])
      expect(described_class.new('a.csv', label: 'sales', value: 'visits').points(metadata:)).to eq([['3', 10], ['4', 20]])
    end

    it "writes why it can't chart a file" do
      expect(rewrite("chart: 'missing.csv'\n", metadata:)).to eq(%(chart: 'missing.csv'\nCan't chart "missing.csv": no such file\n))
    end

    it 'reads the file a variable names' do
      file('downloads.csv', "month,downloads\nJan,2\n")

      expect(rewrite("---\ndata:\n  downloads: downloads.csv\n---\n\nchart: data.downloads width: 2\n", metadata:))
        .to include("chart: data.downloads width: 2\n```\nJan  ██ 2\n```\n")
    end
  end

  it 'charts the data a variable has' do
    content = "---\nstats:\n  ruby: 2\n  go: 1\ntrend: [1, 8]\n---\n\nchart: stats width: 2\n\nchart: trend\n"

    expect(rewrite(content)).to include("chart: stats width: 2\n```\nruby  ██ 2\ngo    █  1\n```\n")
      .and include("chart: trend\n```\n▁█\n```\n")
  end

  it 'skips rows without a number' do
    expect(described_class.new([%w[a 1], ['b', ''], %w[c x]]).points).to eq([['a', 1]])
  end

  describe 'bars' do
    it 'draws eighths of a cell' do
      expect(chart({ a: 8, b: 3 }, width: 2)).to eq("a  ██ 8\nb  ▊  3")
    end

    it 'draws negative values left of a line' do
      expect(chart({ a: 2, b: -2 }, width: 4)).to eq("a    │██  2\nb  ██│   -2")
    end
  end

  describe 'columns' do
    it 'draws columns from a line at zero, with labels below' do
      expect(chart({ Jan: 4, Feb: 2 }, format: 'columns', height: 2)).to eq(<<~CHART.chomp)
        4 ┤ ███
          │ ███ ███
        0 ┼─────────
            Jan Feb
      CHART
    end

    it 'draws negative values below the line' do
      expect(chart({ a: 2, b: -1 }, format: 'columns', height: 3)).to eq(<<~CHART.chomp)
         2 ┤ ███
           │ ███
         0 ┼─────────
        -1 ┤     ███
              a   b
      CHART
    end
  end

  describe 'line' do
    it 'draws a line of braille dots, 2 across and 4 down in each character' do
      expect(chart('0 1 2 3', format: 'line', width: 2, height: 1)).to eq('3 ┤ ⡠⠊')
    end

    it 'draws negative values below a line at zero, with the labels that fit below' do
      expect(chart({ Jan: 4, Feb: -4, Mar: 4 }, format: 'line', width: 9, height: 3)).to eq(<<~CHART.chomp)
         4 ┤ ⠑⡄     ⢀⠎
         0 ┼──⠈⠢⡀──⡰⠁─
        -4 ┤    ⠘⢄⠎
             Jan   Mar
      CHART
    end

    it 'draws values that are all the same along the bottom' do
      expect(chart('5 5', format: 'line', width: 2, height: 2)).to eq("  │\n5 ┤ ⣀⣀")
    end
  end

  describe 'sparkline' do
    it 'draws numbers alone from lowest to highest' do
      expect(chart('1 2 3 4 5 6 7 8')).to eq('▁▂▃▄▅▆▇█')
    end

    it 'draws negative values below a line' do
      expect(chart('4, -8, 8, -4')).to eq("▄ █\n────\n █ ▀")
    end
  end

  it 'is told how to draw with format:' do
    expect(chart('1 2', format: 'pie')).to eq(%(Can't chart "1 2": format: is bars, columns, line, sparkline, not "pie"))
  end
end
