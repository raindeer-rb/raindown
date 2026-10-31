# frozen_string_literal: true

require 'raindown/tui/layout'
require 'raindown/tui/navigator/navigator'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::EnvyMarks do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  before do
    FileUtils.mkdir_p(File.join(@root, 'lib'))
    File.write(File.join(@root, 'lib', 'shapes.rb'), "class Square\n  def area = 1\n  def draw(canvas)\n" \
                                                     "    [canvas.clear, canvas.line, canvas.fill]\n  end\nend\n")
    File.write(File.join(@root, 'lib', 'canvas.rb'), "class Canvas\n  def clear = 1\n  def line = 2\n  def fill = 3\nend\n")
    allow(Dir).to receive(:home).and_return(File.dirname(@root))
  end

  let(:navigator) { Raindown::TUI::Navigator.new(root: @root).tap { it.next_step(:feelings) } }
  let(:envious) { navigator.view.code_methods.index { it.name == 'draw' } }

  def lines(width = 90) = Raindown::TUI::Layout.new(navigator, width:, height: 24).lines
  def bottom(width) = lines(width).map { |segments| segments.map(&:text).join }.find { it.include?('╰') }.rstrip

  it "tints an envious method's digits, and says what it envies at the bottom of its code's box when it's selected" do
    lines
    navigator.view.cursor = navigator.view.code_methods.each_index.find { it != envious }
    cells = lines.flatten.select { it.event == Raindown::TUI::Click.new(pane: :main, index: envious, action: :focus) }

    expect([cells.map(&:style).uniq, bottom(120)]).to match([[:envy], satisfy { !it.include?('💚') }])

    navigator.view.cursor = envious
    expect(bottom(80)).to include('╰─ 💚 envies Canvas: 3 calls').and end_with('… ─╯')
    expect(bottom(120)).to include('╰─ 💚 envies Canvas: 3 calls on canvas, 0 on self ─').and end_with(' c: calm ─╯')
  end

  it "says it's calm with C, which leaves its digits untinted" do
    lines
    navigator.view.cursor = envious
    navigator.next_step(:calm)

    expect(navigator.status).to eq([:info, 'Square#draw is calm, until its code changes'])
    expect(bottom(120)).not_to include('💚')
  end
end
