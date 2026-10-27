# frozen_string_literal: true

require 'raindown/tui/feelings_log'
require 'raindown/tui/code_methods'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::FeelingsLog do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  let(:log) { described_class.new(root: @root) }
  let(:method) do
    Raindown::TUI::CodeMethod.new(path: File.join(@root, 'lib', 'text.rb'), owner: 'Text', name: 'fit', line: 12, lines: [],
                                  changes: 0, drift: 0)
  end

  let(:other) { method.with(name: 'spread', line: 30) }

  def feeling(temper, note = nil, about: method) = Raindown::TUI::Feeling.new(method: about, temper:, note:)

  it 'notes each feeling down in .raindown/feelings.csv, with its code\'s checksum, and counts them by temper' do
    log.add(feeling('malice', 'two negations | and a hidden @rows'))
    log.add(feeling('numb', about: other))

    expect(log.rows.map { it.values_at('where', 'method', 'temper', 'note', 'checksum') })
      .to eq([['lib/text.rb:12', 'Text#fit', 'malice', 'two negations | and a hidden @rows', method.checksum],
              ['lib/text.rb:30', 'Text#spread', 'numb', nil, other.checksum]])
    expect(log.counts).to eq('woe' => 0, 'frolic' => 0, 'dread' => 0, 'malice' => 1, 'numb' => 1)
    expect(File.read(File.join(@root, '.raindown', 'tempers.csv'))).to start_with("temper,feelings\nwoe,0\n")
  end

  it "replaces a feeling about a method whose code hasn't changed, and keeps it once the code has" do
    log.add(feeling('malice'))
    log.add(feeling('numb'))
    expect(log.rows.map { it['temper'] }).to eq(['numb'])

    changed = method.with(lines: ['def fit = 1'])
    expect([log.felt?(method), log.felt?(changed)]).to eq([true, false])

    log.add(feeling('woe', about: changed))
    expect(log.rows.map { it['temper'] }).to eq(%w[numb woe])
  end

  it 'counts a row from before checksums were kept as felt, until the method is felt again' do
    FileUtils.mkdir_p(File.join(@root, '.raindown'))
    File.write(File.join(@root, '.raindown', 'feelings.csv'),
               "when,where,method,temper,note,commit\n2026-10-27,lib/text.rb:12,Text#fit,woe,,\n")
    expect(log.felt?(method)).to be(true)

    log.add(feeling('frolic'))
    expect(log.rows.map { it.values_at('temper', 'checksum') }).to eq([['frolic', method.checksum]])
  end

  it 'writes the feelings page, with a chart of the tempers and a table, newest first' do
    log.add(feeling('woe'))
    log.add(feeling('malice', 'a | b', about: other))
    page = File.read(log.page)

    expect(page).to include("<{ chart: '.raindown/tempers.csv' width: 30 }>\n<{ :chart }>")
    expect(page.lines.grep(/\A\| \d/).map { it.split(' | ')[3] }).to eq(%w[malice woe])
    expect(page).to include('a \\| b')
  end

  it 'asks Claude Code to refactor the method, with how it felt' do
    expect(feeling('dread', 'too clever').prompt).to start_with("Refactor Text#fit in #{method.path}:12. It felt like dread: too clever.")
    expect(feeling(nil).prompt).to include('It needs a second look.')
  end
end
