# frozen_string_literal: true

require 'raindown/tui/layout'
require 'raindown/tui/navigator'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::Layout do
  def click(pane, index, action = :enter) = Raindown::TUI::Click.new(pane:, index:, action:)

  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.join(File.realpath(dir), 'docs')
      FileUtils.mkdir_p(File.join(@root, 'guides'))
      File.write(File.join(@root, 'guides', 'setup.md'),
                 "# Setup\n\n<{ endpoint: }>\n```sh\ncurl https://example.com\n```\n```json\n{}\n```\n<{ :endpoint }>\n")
      File.write(File.join(@root, 'README.md'), "# Readme\n")
      example.run
    end
  end

  # The title shows the project's folder from the home folder.
  before { allow(Dir).to receive(:home).and_return(File.dirname(@root)) }

  let(:setup) { File.join(@root, 'guides', 'setup.md') }
  let(:navigator) { Raindown::TUI::Navigator.new(root: @root, path: setup) }

  def text(lines) = lines.map { |segments| segments.map(&:text).join }
  def width(line) = Unicode::DisplayWidth.of(line)

  # A line's text in the columns from a column, which can differ from its characters, like the title's emoji.
  def columns(line, from:, count:)
    column = 0
    line.map(&:text).join.each_char.select do |char|
      inside = (from...(from + count)).cover?(column)
      column += width(char)
      inside
    end.join
  end

  it 'lays out the title, the files beside the outline, the status and the buttons, each line the full width' do
    lines = described_class.new(navigator, width: 60, height: 7).lines

    expect(text(lines).map(&:rstrip)).to eq(
      [' 🌧️ Raindown  ~/docs › guides/setup.md',
       ' 📊 Dashboard       │ # Setup',
       ' ▾ guides/          │   endpoint:                 [+6] [Run]',
       '   setup.md         │',
       ' README.md          │',
       ' Opened guides/setup.md',
       ' Tab Pane  Enter Open  X Run  E dit  W rite back  R eload']
    )
    expect(text(lines).drop(1).map { width(it) }).to all(eq(60))
    # The rain cloud is measured as wide as the terminal draws it, where that's known, and the title stops short of it.
    expect(width(text(lines).first)).to eq(59)
  end

  it 'highlights the cursor, brightly in the focused pane' do
    lines = described_class.new(navigator, width: 60, height: 7).lines

    expect(lines[1].last.style).to eq(:selected)
    expect(lines[3].first.style).to eq(:cursor)
    expect(lines[1].first.style).to eq(:dashboard)
    expect(lines[2].last(2).map(&:style)).to eq(%i[button button])
  end

  it 'sends events from rows and buttons when clicked' do
    lines = described_class.new(navigator, width: 80, height: 7).lines

    expect(lines[1].first.event).to eq(click(:files, 0))
    expect(lines[1].last.event).to eq(click(:outline, 0))
    expect(lines[2].last.event).to eq(click(:outline, 1, :execute))
    expect(lines.last.map(&:event).compact.uniq).to eq(%i[tab enter execute edit write_back reload quit])
  end

  it 'cuts text that does not fit, and leaves out buttons that do not fit' do
    lines = described_class.new(navigator, width: 30, height: 7).lines

    expect(text(lines).first).to start_with(' 🌧️ Raindown  ~/docs › ').and end_with('…')
    expect(text(lines).drop(1).map { width(it) }).to all(eq(30))
    expect(lines.last.map(&:event).compact.uniq).to eq(%i[tab enter execute])
  end

  it "shows the project's folder in full when it's outside the home folder" do
    allow(Dir).to receive(:home).and_return('/elsewhere')

    expect(text(described_class.new(navigator, width: 200, height: 7).lines).first.rstrip)
      .to eq(" 🌧️ Raindown  #{@root} › guides/setup.md")
  end

  it 'shows only the status when the screen is too short for the panes' do
    expect(text(described_class.new(navigator, width: 20, height: 2).lines).map(&:rstrip)).to eq([' Opened guides/setu…'])
  end

  describe 'the dashboard' do
    before do
      File.write(File.join(@root, 'stats.md'), "# Stats\n\n<{ chart: '1 2 3' }>\n<{ :chart }>\n\n<{ chart: '3 2 1' }>\n<{ :chart }>\n")
    end

    let(:navigator) { Raindown::TUI::Navigator.new(root: @root) }

    # The dashboard's side of each line, right of the files.
    def main(lines) = text(lines).map { it.split('│', 2)[1].to_s.rstrip }

    it 'shows each chart in a card beside the files, with as many in a row as fit' do
      lines = described_class.new(navigator, width: 90, height: 8).lines

      expect(text(lines).first.rstrip).to eq(' 🌧️ Raindown  ~/docs › Dashboard')
      expect(text(lines)[1]).to start_with(' 📊 Dashboard ')
      expect(main(lines)[1..4]).to eq([' stats.md › Stats           stats.md › Stats',
                                       " chart: '1 2 3'             chart: '3 2 1'",
                                       ' ▁▅█                        █▅▁', ''])
      expect(text(lines).last.rstrip).to eq(' Tab Pane  Enter Open  E dit  R eload  Q uit')
      expect(text(lines).drop(1).map { width(it) }).to all(eq(90))
    end

    it 'opens a chart when its title is clicked, and highlights the selected one while the dashboard has the focus' do
      lines = described_class.new(navigator, width: 90, height: 8).lines
      titles = lines[1].select { it.event&.pane == :dashboard }

      expect(titles.map(&:event)).to eq([click(:dashboard, 0), click(:dashboard, 1)])
      expect(titles.map(&:style)).to eq(%i[cursor heading])

      navigator.handle(:tab)
      expect(described_class.new(navigator, width: 90, height: 8).lines[1].find { it.event == click(:dashboard, 0) }.style)
        .to eq(:selected)
    end

    it 'puts the cards in rows below each other when they do not fit beside each other' do
      lines = described_class.new(navigator, width: 60, height: 12).lines

      expect(main(lines)[1..8]).to eq([' stats.md › Stats', " chart: '1 2 3'", ' ▁▅█', '',
                                       ' stats.md › Stats', " chart: '3 2 1'", ' █▅▁', ''])
    end
  end

  describe 'the dashboard with projects inside the folder' do
    let(:navigator) { Raindown::TUI::Navigator.new(root: @root) }

    before do
      FileUtils.mkdir_p(File.join(@root, '.raindown'))
      File.write(File.join(@root, 'stats.md'), "<{ chart: '1 2 3' }>\n<{ :chart }>\n")
      FileUtils.mkdir_p(File.join(@root, 'guides', '.raindown'))
      File.write(File.join(@root, 'guides', 'more.md'), "# More\n\n<{ chart: '3 2 1' }>\n<{ :chart }>\n")
    end

    def main(lines) = text(lines).map { it.split('│', 2)[1].to_s.rstrip }

    it "puts each project's charts under its path from the home folder, titled from the project" do
      lines = described_class.new(navigator, width: 90, height: 14).lines

      expect(main(lines)[1..9]).to eq([' ~/docs', ' stats.md', " chart: '1 2 3'", ' ▁▅█', '',
                                       ' ~/docs/guides', ' more.md › More', " chart: '3 2 1'", ' █▅▁'])
      expect(lines[1].last.style).to eq(:project)
    end
  end

  describe 'the project menu' do
    let(:navigator) { Raindown::TUI::Navigator.new(root: @root) }

    before { FileUtils.mkdir_p(File.join(@root, 'guides', '.raindown')) }

    it 'has a Projects button on the dashboard' do
      expect(described_class.new(navigator, width: 80, height: 8).lines.last.map(&:event).compact.uniq)
        .to eq(%i[tab enter edit projects reload quit])
    end

    it "opens from the header's path, and drops down below it over the panes, each project clicked to choose it" do
      expect(described_class.new(navigator, width: 60, height: 8).lines.first.find(&:event).to_h)
        .to include(text: '~/docs ▾', event: :projects)

      navigator.handle(:projects)
      lines = described_class.new(navigator, width: 60, height: 8).lines
      menu = lines[1..5].map { columns(it, from: width(' 🌧️ Raindown  '), count: 21) }

      expect(menu).to eq(['┌───────────────────┐', '│ All projects    ✓ │', '│ ~/docs            │',
                          '│ ~/docs/guides     │', '└───────────────────┘'])
      expect(lines[2].find { it.event == click(:menu, 0) }.style).to eq(:selected)
      expect(lines[4].find { it.event == click(:menu, 2) }).not_to be_nil
      expect(text(lines).drop(1).map { width(it) }).to all(eq(60))
    end
  end
end
