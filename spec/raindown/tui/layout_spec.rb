# frozen_string_literal: true

require 'raindown/tui/layout'
require 'raindown/tui/navigator/navigator'
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

  it 'lays out the title, the files beside the outline below a blank line, the status and the buttons, each line the full width' do
    lines = described_class.new(navigator, width: 60, height: 14).lines

    expect(text(lines).map(&:rstrip)).to eq(
      [' 🌧  Raindown  ~/docs › guides/setup.md',
       '                    ▏',
       ' 📊 Dashboard       ▏ # Setup',
       '                    ▏   endpoint:                 [+6] [Run]',
       ' ▾ guides/          ▏',
       '   setup.md         ▏',
       ' README.md          ▏',
       '                    ▏',
       ' GET example.com    ▏',
       '                    ▏',
       '                    ▏',
       '                    ▏',
       ' Opened guides/setup.md',
       ' Tab Pane  Enter Open  X Run  E dit  W rite back  R eload']
    )
    expect(text(lines).map { width(it) }).to all(eq(60))
  end

  it 'highlights the cursor in the focused pane, and dimmer in the others, with the divider beside the outline\'s' do
    lines = described_class.new(navigator, width: 60, height: 14).lines
    divider = ->(line) { line.find { it.text == described_class::DIVIDER }.style }

    expect(lines[2].last.style).to eq(:selected)
    expect(lines[5].first.style).to eq(:cursor)
    expect([lines[3].first.style, lines[3].first.event]).to eq([:blank, nil])
    expect([divider[lines[1]], divider[lines[2]], divider[lines[3]]]).to eq(%i[divider selected_divider divider])
    navigator.next_step(:left)
    lines = described_class.new(navigator, width: 60, height: 14).lines
    expect([lines[2].last.style, lines[5].first.style, divider[lines[2]]]).to eq(%i[cursor selected cursor_divider])
    expect(lines[2].first.style).to eq(:dashboard)
    expect(lines[3].last(2).map(&:style)).to eq(%i[button button])
  end

  it 'sends events from rows and buttons when clicked' do
    lines = described_class.new(navigator, width: 80, height: 14).lines

    expect(lines[2].first.event).to eq(click(:nav, 0))
    expect(lines[4].first.event).to eq(click(:nav, 2))
    expect(lines[8].first.event).to eq(click(:nav, 6))
    expect(lines[7].first.event).to be_nil
    expect(lines[2].last.event).to eq(click(:main, 0))
    expect(lines[3].last.event).to eq(click(:main, 1, :execute))
    expect(lines.last.map(&:event).compact.uniq).to eq(%i[tab enter execute edit write_back reload search quit])
  end

  it 'cuts text that does not fit, and leaves out buttons that do not fit' do
    lines = described_class.new(navigator, width: 30, height: 7).lines

    expect(text(lines).first).to start_with(' 🌧  Raindown  ~/docs › ').and end_with('…')
    expect(text(lines).drop(1).map { width(it) }).to all(eq(30))
    expect(lines.last.map(&:event).compact.uniq).to eq(%i[tab enter execute])
  end

  it "shows the project's folder in full when it's outside the home folder" do
    allow(Dir).to receive(:home).and_return('/elsewhere')

    expect(text(described_class.new(navigator, width: 200, height: 7).lines).first.rstrip)
      .to eq(" 🌧  Raindown  #{@root} › guides/setup.md")
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
    def main(lines) = text(lines).map { it.split('▏', 2)[1].to_s.rstrip }

    it 'shows each chart in a card with a rounded border beside the files, with as many in a row as fit' do
      lines = described_class.new(navigator, width: 90, height: 10).lines

      expect(text(lines).first.rstrip).to eq(' 🌧  Raindown  ~/docs › Dashboard')
      expect(text(lines)[2]).to start_with(' 📊 Dashboard ')
      expect(main(lines)[2..6]).to eq([' ╭──────────────────────────╮  ╭──────────────────────────╮',
                                       ' │ stats.md › Stats         │  │ stats.md › Stats         │',
                                       " │ chart: '1 2 3'           │  │ chart: '3 2 1'           │",
                                       ' │ ▁▅█                      │  │ █▅▁                      │',
                                       ' ╰──────────────────────────╯  ╰──────────────────────────╯'])
      expect(text(lines).last.rstrip).to eq(' Tab Pane  Enter Open  E dit  R eload  / Search  Q uit')
      expect(text(lines).drop(1).map { width(it) }).to all(eq(90))
    end

    it 'opens a chart when its title is clicked, and highlights the selected one while the dashboard has the focus' do
      lines = described_class.new(navigator, width: 90, height: 10).lines
      titles = lines[3].select { it.event&.pane == :main && it.style != :border }

      expect(titles.map(&:event)).to eq([click(:main, 0), click(:main, 1)])
      expect(titles.map(&:style)).to eq(%i[selected heading])
      expect(lines[2].map(&:event).select { it&.pane == :main }).to eq([click(:main, 0), click(:main, 1)])

      navigator.next_step(:tab)
      line = described_class.new(navigator, width: 90, height: 10).lines[3]
      title = line.find { it.event == click(:main, 0) && it.style != :border }
      expect(title.style).to eq(:cursor)
    end

    it "doesn't click the space below a card shorter than its row" do
      columns = "<{ chart: '1 2 3' height: 3 format: 'columns' }>\n<{ :chart }>\n"
      File.write(File.join(@root, 'stats.md'), "<{ chart: '1 2 3' }>\n<{ :chart }>\n\n#{columns}")
      navigator.next_step(:reload)
      lines = described_class.new(navigator, width: 90, height: 13).lines

      clicks = ->(line) { lines[line].map(&:event).select { it&.pane == :main }.map(&:index).uniq }
      expect([clicks[6], clicks[7]]).to eq([[0, 1], [1]])
    end

    it 'fits the cards to a pane narrower than a card can be' do
      lines = described_class.new(navigator, width: 40, height: 9).lines

      expect(text(lines).drop(1).map { width(it) }).to all(eq(40))
      expect(main(lines)[3]).to start_with(' │ stats.md › Stats')
    end

    it 'puts the cards in rows below each other when they do not fit beside each other' do
      lines = described_class.new(navigator, width: 60, height: 17).lines

      expect(main(lines)[2..13]).to eq([' ╭──────────────────────────╮', ' │ stats.md › Stats         │', " │ chart: '1 2 3'           │",
                                        ' │ ▁▅█                      │', ' ╰──────────────────────────╯', '',
                                        ' ╭──────────────────────────╮', ' │ stats.md › Stats         │', " │ chart: '3 2 1'           │",
                                        ' │ █▅▁                      │', ' ╰──────────────────────────╯', ''])
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

    def main(lines) = text(lines).map { it.split('▏', 2)[1].to_s.rstrip }

    it "puts each project's charts under its path from the home folder, titled from the project" do
      lines = described_class.new(navigator, width: 90, height: 19).lines

      expect(main(lines)[2..14]).to eq([' ~/docs', ' ╭──────────────────────────╮', ' │ stats.md                 │',
                                        " │ chart: '1 2 3'           │",
                                        ' │ ▁▅█                      │', ' ╰──────────────────────────╯', '',
                                        ' ~/docs/guides', ' ╭──────────────────────────╮', ' │ more.md › More           │',
                                        " │ chart: '3 2 1'           │", ' │ █▅▁                      │', ' ╰──────────────────────────╯'])
      expect(lines[2].last.style).to eq(:project)
    end
  end

  describe 'the project menu' do
    let(:navigator) { Raindown::TUI::Navigator.new(root: @root) }

    before { FileUtils.mkdir_p(File.join(@root, 'guides', '.raindown')) }

    it 'has a Projects button on the dashboard' do
      expect(described_class.new(navigator, width: 80, height: 8).lines.last.map(&:event).compact.uniq)
        .to eq(%i[tab enter edit projects reload search quit])
    end

    it "opens from the header's path, and drops down below it over the panes, each project clicked to choose it" do
      expect(described_class.new(navigator, width: 60, height: 8).lines.first.find(&:event).to_h)
        .to include(text: '~/docs ▾', event: :projects)

      navigator.next_step(:projects)
      lines = described_class.new(navigator, width: 60, height: 8).lines
      menu = lines[1..5].map { columns(it, from: width(' 🌧  Raindown  '), count: 21) }

      expect(menu).to eq(['┌───────────────────┐', '│ All projects    ✓ │', '│ ~/docs            │',
                          '│ ~/docs/guides     │', '└───────────────────┘'])
      expect(lines[2].find { it.event == click(:menu, 0) }.style).to eq(:selected)
      expect(lines[4].find { it.event == click(:menu, 2) }).not_to be_nil
      expect(text(lines).drop(1).map { width(it) }).to all(eq(60))
    end
  end

  describe 'an endpoint' do
    let(:navigator) { Raindown::TUI::Navigator.new(root: @root) }

    before do
      File.write(File.join(@root, 'api.md'), "<{ endpoint: }>\n```sh\ncurl -X DELETE https://api.example.com/users/1\n```\n" \
                                             "```json\n{}\n```\n<!-- raindown:fetched 2026-10-26 -->\n<{ :endpoint }>\n")
    end

    def main(lines) = text(lines).map { it.split('▏', 2)[1].to_s.rstrip }
    def endpoint_row(lines) = lines.index { |line| line.any? { it.style == :method_delete } }

    it 'lists the method in its colour in the files' do
      lines = described_class.new(navigator, width: 100, height: 14).lines
      row = lines[endpoint_row(lines)]

      expect(row.map { [it.text.strip, it.style] }.first(2)).to eq([['DELETE', :method_delete], ['api.example.com/users/1', :endpoint]])
    end

    it 'shows its URL in a bar with rounded corners and a button to run it, then its response' do
      navigator.next_step(click(:nav, navigator.content(:nav).rows.index { it.kind == :endpoint }))
      lines = described_class.new(navigator, width: 90, height: 12).lines

      expect(main(lines)[2..7]).to eq([' ╭───────────────────────────────────────────────────────╮',
                                       ' │ DELETE https://api.example.com/users/1        [ Run ] │',
                                       ' ╰───────────────────────────────────────────────────────╯',
                                       '', ' Response · json · fetched 2026-10-26', ' {}'])
      expect(lines[3].find { it.text == '[ Run ]' }.event).to eq(click(:main, 0, :execute))
      expect(lines[3].find { it.text == 'DELETE' }.style).to eq(:method_delete)
      expect(text(lines).first).to include('› DELETE api.example.com/users/1')
      expect(text(lines).drop(1).map { width(it) }).to all(eq(90))
    end
  end

  describe 'the search' do
    it 'drops down below the title over the panes, with what\'s typed and the matches, each clicked to open it' do
      navigator.next_step(:search)
      'setup'.each_char { navigator.next_step(Raindown::TUI::Type.new(text: it)) }
      lines = described_class.new(navigator, width: 60, height: 14).lines

      # The box is the width less 4, between 2 columns either side.
      expect(lines[1..4].map { columns(it, from: 2, count: 56) }).to eq(
        ['┌─ Teleport ───────────────────────────────────────────┐',
         '│ / setup▏                                             │',
         '│ # Setup                            guides/setup.md:1 │',
         '│ guides/setup.md                                      │']
      )
      expect(lines[3].map(&:event).compact.uniq.select { it.pane == :search }).to eq([click(:search, 0)])
      expect(lines[3].find { it.text.include?('# Setup') }.style).to eq(:selected)
      expect(text(lines).map { width(it) }).to all(eq(60))
    end
  end
end
