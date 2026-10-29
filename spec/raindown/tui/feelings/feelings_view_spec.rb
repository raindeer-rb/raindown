# frozen_string_literal: true

require 'raindown/tui/feelings/feelings_view'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::FeelingsView do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  # Drawn once, as it is when it opens, which picks the batch.
  let(:view) do
    described_class.new(root: @root).tap do
      it.load
      it.cells(2, 2)
    end
  end

  before do
    FileUtils.mkdir_p(File.join(@root, 'lib'))
    File.write(File.join(@root, 'lib', 'shapes.rb'), "class Square\n  def area = 1\n  def side = 2\n  def draw = 3\nend\n")
  end

  def type(text) = text.each_char { view.next_step(Raindown::TUI::Type.new(text: it)) }

  it 'lays the methods out as cells, a run of them each, and moves along them and between rows' do
    expect(view.cells(2)).to eq([0, 1, 2])

    view.next_step(:down)
    expect(view.cursor).to eq(2)
    view.next_step(:up)
    expect(view.cursor).to eq(0)

    view.next_step(:right)
    view.next_step(:down)
    expect(view.cursor).to eq(1)
  end

  it 'notes down a frolic or numb feeling straight away, staying on the method' do
    first = view.selected
    step = view.next_step(:bin1)

    expect(step).to eq(Raindown::TUI::Felt.new(feeling: step.feeling))
    expect([step.feeling.temper, step.feeling.method, view.cursor]).to eq(['frolic', first, 0])
    expect(view.log.counts['frolic']).to eq(1)
  end

  it "moves a feeling to the memories when the method's code changes, and it's read again" do
    view.cursor = view.code_methods.index { it.name == 'side' }
    view.next_step(:bin1)
    File.write(File.join(@root, 'lib', 'shapes.rb'), "class Square\n  def area = 1\n  def side = 4\n  def draw = 3\nend\n")
    view.load

    expect([view.log.rows, File.read(File.join(@root, '.raindown', 'memories.csv'))]).to match([[], include('Square#side,frolic')])
    expect(view.batch.felt?(view.code_methods.find { it.name == 'side' })).to be(false)
  end

  it 'keeps the selected method when the code is read again, like after a fix that adds methods around it' do
    view.cursor = view.code_methods.index { it.name == 'draw' }
    methods = (1..6).map { "  def extracted#{it} = #{it}\n" }.join
    File.write(File.join(@root, 'lib', 'shapes.rb'), "class Square\n#{methods}  def area = 1\n  def side = 2\n  def draw = 3\nend\n")
    view.load

    expect([view.selected.name, view.code_methods.length]).to eq(['draw', 9])
  end

  it 'asks why for woe, dread and malice, taking every key typed until Enter, or Esc to leave it out, and stays' do
    expect(view.next_step(:bin5)).to be_nil
    expect([view.typing?, view.noting, view.next_step?(:tab)]).to eq([true, 'malice', true])

    type('two jq')
    view.next_step(:backspace)
    step = view.next_step(:enter)
    expect([step.feeling.temper, step.feeling.note, view.typing?, view.cursor]).to eq(['malice', 'two j', false, 0])

    view.next_step(:bin3)
    expect(view.next_step(:escape).feeling.note).to be_nil
  end

  it 'opens the selected method in the editor, or asks to fix it with how it last felt' do
    expect(view.next_step(:edit)).to eq(Raindown::TUI::Edit.new(path: File.join(@root, 'lib', 'shapes.rb'), line: view.selected.line))
    expect(view.next_step(:execute).feeling.temper).to be_nil

    view.next_step(:bin4)
    view.next_step(:enter)
    view.next_step(:left)
    expect(view.next_step(:execute).feeling.temper).to eq('dread')
  end

  it "shows all the selected method's code with Enter, Space or a click, until another's selected" do
    view.next_step(:enter)
    expect(view.expanded).to be(true)
    view.next_step(:expand)
    expect(view.expanded).to be(false)

    view.next_step(:toggle)
    view.next_step(:right)
    expect(view.expanded).to be(false)
  end

  it "fills the grid with the week's first files, which stay the same once they're refined, even after a restart" do
    FileUtils.mkdir_p(File.join(@root, 'more'))
    5.times { File.write(File.join(@root, 'more', "f#{it}.rb"), "def f#{it} = 1\n") }
    view.load
    view.cells(2, 2)
    batch = view.batch.files

    expect([view.code_methods.sum(&:size), view.code_methods.map(&:path).uniq.sort]).to eq([4, batch.sort])
    expect(view.batch.progress).to eq('0% refined')

    view.code_methods.each_index do
      view.cursor = it
      view.next_step(:bin2)
    end
    restarted = described_class.new(root: @root).tap(&:load).tap { it.cells(2, 2) }
    expect([restarted.batch.files, restarted.batch.progress, restarted.next_step?(:next)]).to eq([batch, '100% refined', false])
  end

  it 'rains when the last of the batch is felt, then shows a waffle until a key is pressed, or with Ctrl+T to try it' do
    view.code_methods.each_index do
      view.cursor = it
      view.next_step(:bin2)
    end
    expect([view.celebration.frame, view.pace(nil)]).to eq([0, :animation])

    Raindown::TUI::Celebration::RAIN_FRAMES.times { view.next_step(:tick) }
    expect([view.celebration.raining?, view.pace(nil), view.next_step?(:tab)]).to eq([false, :animation, true])

    view.next_step(:right)
    expect([view.celebration, view.batch.progress]).to eq([nil, '100% refined'])
    view.next_step(:bin1)
    expect(view.celebration).to be_nil

    expect([view.next_step(:celebrate), view.pace(nil)]).to eq([nil, :animation])
  end

  it 'picks the same files all week' do
    8.times { File.write(File.join(@root, "f#{it}.rb"), "def f#{it} = 1\n") }
    every = Raindown::TUI::CodeMethods.list(@root)
    pick = ->(date) { Raindown::TUI::Batch.pick(every, log: view.log, cells: 1, week: Raindown::TUI::Batch.this_week(date)).files }

    expect([Raindown::TUI::Batch.this_week(Date.new(2026, 10, 27)), pick.call(Date.new(2026, 10, 26))])
      .to eq(['2026-W44', pick.call(Date.new(2026, 11, 1))])
    expect((1..8).map { pick.call(Date.new(2026, 11, 1) + (7 * it)) }.uniq.length).to be > 1
  end

  it 'leaves Tab, and left from the first method, to the files' do
    expect([view.next_step?(:tab), view.next_step?(:left), view.next_step?(:right)]).to eq([false, false, true])
  end

  it 'is drawn often, wherever the mouse is, and most often while it rains' do
    over = Raindown::TUI::Click.new(pane: :main, index: 0, action: :focus)
    expect([nil, over].map { view.pace(it) }).to eq(%i[reactive reactive])

    view.next_step(:celebrate)
    expect(view.pace(over)).to eq(:animation)
  end
end
