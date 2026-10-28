# frozen_string_literal: true

require 'raindown/tui/feelings/feelings_log'
require 'raindown/tui/feelings/code_methods'
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

    expect(log.rows.map { it.values_at(:where, :method, :temper, :note, :checksum) })
      .to eq([['lib/text.rb:12', 'Text#fit', 'malice', 'two negations | and a hidden @rows', method.checksum],
              ['lib/text.rb:30', 'Text#spread', 'numb', nil, other.checksum]])
    expect(log.counts).to eq('frolic' => 0, 'hope' => 0, 'numb' => 1, 'woe' => 0, 'dread' => 0, 'malice' => 1)
  end

  def memories = CSV.read(File.join(@root, '.raindown', 'memories.csv'), headers: true).map { it.to_h.values_at('method', 'temper') }

  it "replaces a feeling about a method whose code hasn't changed, and moves it to the memories once the code has" do
    log.add(feeling('malice'))
    log.add(feeling('numb'))
    expect(log.rows.map { it[:temper] }).to eq(['numb'])

    changed = method.with(lines: ['def fit = 1'])
    expect([log.felt?(method), log.felt?(changed)]).to eq([true, false])
    expect([log.temper(method), log.temper(changed)]).to eq(['numb', nil])

    log.add(feeling('woe', about: changed))
    expect([log.rows.map { it[:temper] }, memories]).to eq([['woe'], [%w[Text#fit numb]]])
  end

  it 'moves the feelings about methods that have changed or gone to the memories, keeping the rest' do
    log.add(feeling('malice'))
    log.add(feeling('numb', about: other))
    log.add(feeling('dread', about: other.with(name: 'gone', line: 50)))

    log.move_stale_to_memories([method, other.with(lines: ['def spread = 2'])])
    expect([log.rows.map { it[:temper] }, memories]).to eq([['malice'], [%w[Text#spread numb], %w[Text#gone dread]]])
    expect(log.counts.values.sum).to eq(1)

    log.move_stale_to_memories([method])
    expect(memories.length).to eq(2)
  end

  it 'counts a row from before checksums were kept as felt, while its method is there, until the method is felt again' do
    FileUtils.mkdir_p(File.join(@root, '.raindown'))
    File.write(File.join(@root, '.raindown', 'feelings.csv'),
               "when,where,method,temper,note,commit\n2026-10-27,lib/text.rb:12,Text#fit,woe,,\n")
    expect(log.felt?(method)).to be(true)

    log.move_stale_to_memories([method])
    expect(log.felt?(method)).to be(true)
    log.move_stale_to_memories([other])
    expect(log.felt?(method)).to be(false)

    log.add(feeling('frolic'))
    expect(log.rows.map { it.values_at(:temper, :checksum) }).to eq([['frolic', method.checksum]])
  end

  it 'writes only .raindown/feelings.csv' do
    log.add(feeling('woe'))

    expect(Dir.glob('**/*', File::FNM_DOTMATCH, base: @root).select { File.file?(File.join(@root, it)) }).to eq(['.raindown/feelings.csv'])
  end

  it 'asks Claude Code to refactor the method, with how it felt' do
    expect(feeling('dread', 'too clever').prompt).to start_with("Refactor Text#fit in #{method.path}:12. It felt like dread: too clever.")
    expect(feeling(nil).prompt).to include('It needs a second look.')
  end
end
