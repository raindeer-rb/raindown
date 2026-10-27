# frozen_string_literal: true

require 'raindown/tui/views/feelings_view'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::FeelingsView do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  let(:view) { described_class.new(root: @root).tap(&:load) }

  before do
    FileUtils.mkdir_p(File.join(@root, 'lib'))
    File.write(File.join(@root, 'lib', 'shapes.rb'), "class Square\n  def area = 1\n  def side = 2\n  def draw = 3\nend\n")
  end

  def type(text) = text.each_char { view.next_step(Raindown::TUI::Type.new(text: it)) }

  it 'lays the methods out as cells, a run of them each, and moves along them and between rows' do
    expect(view.cells(2)).to eq([0, 1, 2])

    view.next_step(:down)
    expect(view.selected.label).to eq('Square#draw')
    view.next_step(:up)
    expect(view.cursor).to eq(0)

    view.next_step(:right)
    view.next_step(:down)
    expect(view.selected.label).to eq('Square#side')
  end

  it "notes down a frolic or numb feeling straight away, and moves on, so the next method's shown" do
    step = view.next_step(:bin2)

    expect(step).to eq(Raindown::TUI::Felt.new(feeling: step.feeling, page: File.join(@root, 'docs', 'code-feelings.md')))
    expect([step.feeling.temper, step.feeling.method.label, view.cursor]).to eq(['frolic', 'Square#area', 1])
    expect(view.log.counts['frolic']).to eq(1)
  end

  it 'asks why for woe, dread and malice, taking every key typed until Enter, or Esc to leave it out, and stays' do
    expect(view.next_step(:bin4)).to be_nil
    expect([view.typing?, view.noting, view.next_step?(:tab)]).to eq([true, 'malice', true])

    type('two jq')
    view.next_step(:backspace)
    step = view.next_step(:enter)
    expect([step.feeling.temper, step.feeling.note, view.typing?, view.cursor]).to eq(['malice', 'two j', false, 0])

    view.next_step(:bin1)
    expect(view.next_step(:escape).feeling.note).to be_nil
  end

  it 'opens the selected method in the editor, or asks to fix it with how it last felt' do
    expect(view.next_step(:edit)).to eq(Raindown::TUI::Edit.new(path: File.join(@root, 'lib', 'shapes.rb'), line: 2))
    expect(view.next_step(:execute).feeling.temper).to be_nil

    view.next_step(:bin3)
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

  it 'drifts with each tick, and leaves Tab, and left from the first method, to the files' do
    expect { view.next_step(:tick) }.to change(view, :tick).by(1)
    expect([view.next_step?(:tab), view.next_step?(:left), view.next_step?(:right)]).to eq([false, false, true])
  end
end
