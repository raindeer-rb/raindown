# frozen_string_literal: true

require 'raindown/tui/layout'
require 'raindown/tui/navigator/navigator'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::SketchesView do
  def click(pane, index, action = :enter) = Raindown::TUI::Click.new(pane:, index:, action:)
  def view_name(navigator) = navigator.view.class.name.delete_prefix('Raindown::TUI::')
  def text(lines) = lines.map { |segments| segments.map(&:text).join }
  def width(line) = Unicode::DisplayWidth.of(line)
  def texts(navigator, pane) = navigator.content(pane).rows.select(&:selectable?).map(&:text)

  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      FileUtils.mkdir_p(File.join(@root, '.raindown'))
      example.run
    end
  end

  def write(name, content)
    File.join(@root, name).tap { File.write(it, content) }
  end

  def sketch(time, kind, drawing) = "## #{time} · #{kind}\n\n```#{kind}\n#{drawing}\n```\n\n"
  def file = File.join(@root, '.raindown', 'sketches.md')

  it "lists Sketches once Claude Code's are saved, newest first, the arrows moving between them, and E editing one" do
    navigator = Raindown::TUI::Navigator.new(root: @root)
    expect(texts(navigator, :nav)).not_to include('🎨 Sketches')

    write('.raindown/sketches.md', sketch('2026-10-30T01:00:00Z', 'mockup', '╭─ old ─╮') +
                                   sketch('2026-10-30T02:00:00Z', 'diagram', 'A ─▶ B'))
    navigator.next_step(click(:nav, navigator.content(:nav).rows.index { it.text == '🎨 Sketches' }))
    expect([view_name(navigator), navigator.view.selected.lines]).to eq(['SketchesView', ['A ─▶ B']])

    navigator.next_step(:right)
    expect(navigator.view.selected.lines).to eq(['╭─ old ─╮'])
    expect(navigator.next_step(:edit)).to be_a(Raindown::TUI::Run)

    File.write(file, sketch('2026-10-30T03:00:00Z', 'chart', '▁▃▅█'), mode: 'a')
    File.utime(Time.now + 5, Time.now + 5, file)
    navigator.next_step(:tick)
    expect([navigator.view.cursor, navigator.view.selected.lines]).to eq([0, ['▁▃▅█']])
  end

  it 'filters the sketches to a kind chosen from the title, with Enter, the arrows and Enter again, or a click' do
    write('.raindown/sketches.md', sketch('2026-10-30T01:00:00Z', 'mockup', 'one') + sketch('2026-10-30T02:00:00Z', 'diagram', 'two') +
                                   sketch('2026-10-30T03:00:00Z', 'mockup', 'three'))
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.sketches)
    view = navigator.view
    expect(view.kinds.first(3)).to eq([[nil, 3], ['mockup', 2], ['diagram', 1]])

    navigator.next_step(:enter)
    navigator.next_step(:down)
    navigator.next_step(:enter)
    expect([view.menu, view.kind, view.sketches.map(&:lines)]).to eq([nil, 'mockup', [['three'], ['one']]])

    navigator.next_step(:kinds)
    expect(view.menu).to eq(1)
    navigator.next_step(click(:main, view.cursor, 0))
    expect([view.kind, view.sketches.length]).to eq([nil, 3])
  end

  it "draws Claude Code's sketches below the kind they're filtered to, which drops down the kinds with how many of each" do
    FileUtils.mkdir_p(File.join(@root, '.raindown'))
    File.write(File.join(@root, '.raindown', 'sketches.md'),
               "## 2026-10-30T03:14:07Z · mockup\n\n```mockup\n╭─ Idea ─╮\n╰────────╯\n```\n")
    navigator = Raindown::TUI::Navigator.new(root: @root)
    navigator.open_view(navigator.sketches)
    draw = -> { Raindown::TUI::Layout.new(navigator, width: 60, height: 14).lines }
    main = ->(lines) { text(lines).map { it.split(/[│┬]/, 2)[1].to_s.rstrip } }

    lines = draw.call
    expect(main[lines][1]).to match(/\A─+ All sketches ▾ ─+\z/)
    expect(main[lines][2..5]).to eq([' 1 of 1 · 2026-10-30 03:14 UTC · mockup', '', ' ╭─ Idea ─╮', ' ╰────────╯'])

    navigator.next_step(:enter)
    menu = main[draw.call][2..9].map(&:strip)
    expect(menu).to include(match(/│ All ✓ +1 │/), match(/│ Mockups +1 │/), match(/│ Charts +0 │/))
    expect(text(draw.call).map { width(it) }).to all(eq(60))
  end
end
