# frozen_string_literal: true

require 'raindown/tui/feelings_log'
require 'raindown/tui/code_methods'
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

  def feeling(temper, note = nil) = Raindown::TUI::Feeling.new(method:, temper:, note:)

  it 'notes each feeling down in .raindown/feelings.csv, and counts them by temper' do
    log.add(feeling('malice', 'two negations | and a hidden @rows'))
    log.add(feeling('numb'))

    expect(log.rows.map { it.values_at('where', 'method', 'temper', 'note') })
      .to eq([['lib/text.rb:12', 'Text#fit', 'malice', 'two negations | and a hidden @rows'], ['lib/text.rb:12', 'Text#fit', 'numb', nil]])
    expect(log.counts).to eq('woe' => 0, 'frolic' => 0, 'dread' => 0, 'malice' => 1, 'numb' => 1)
    expect(File.read(File.join(@root, '.raindown', 'tempers.csv'))).to start_with("temper,feelings\nwoe,0\n")
  end

  it 'writes the feelings page, with a chart of the tempers and a table, newest first' do
    log.add(feeling('woe'))
    log.add(feeling('malice', 'a | b'))
    page = File.read(log.page)

    expect(page).to include("<{ chart: '.raindown/tempers.csv' width: 30 }>\n<{ :chart }>")
    expect(page.lines.grep(/\A\| \d/).map { it.split(' | ')[3] }).to eq(%w[malice woe])
    expect(page).to include('a \| b')
  end

  it 'asks Claude Code to refactor the method, with how it felt' do
    expect(feeling('dread', 'too clever').prompt).to start_with("Refactor Text#fit in #{method.path}:12. It felt like dread: too clever.")
    expect(feeling(nil).prompt).to include('It needs a second look.')
  end
end
