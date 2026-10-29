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
       ' 🎭 Feelings        ▏   endpoint:                 [+6] [Run]',
       '                    ▏',
       ' ▾ guides/          ▏',
       '   setup.md         ▏',
       ' README.md          ▏',
       '                    ▏',
       ' GET example.com    ▏',
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
    expect(lines[6].first.style).to eq(:cursor)
    expect([lines[4].first.style, lines[4].first.event]).to eq([:blank, nil])
    expect([divider[lines[1]], divider[lines[2]], divider[lines[3]]]).to eq(%i[divider selected_divider divider])
    navigator.next_step(:left)
    lines = described_class.new(navigator, width: 60, height: 14).lines
    expect([lines[2].last.style, lines[6].first.style, divider[lines[2]]]).to eq(%i[cursor selected cursor_divider])
    expect([lines[2].first.style, lines[3].first.style]).to eq(%i[page page])
    expect(lines[3].last(2).map(&:style)).to eq(%i[button button])
  end

  it 'sends events from rows and buttons when clicked' do
    lines = described_class.new(navigator, width: 80, height: 14).lines

    expect(lines[2].first.event).to eq(click(:nav, 0))
    expect(lines[3].first.event).to eq(click(:nav, 1))
    expect(lines[5].first.event).to eq(click(:nav, 3))
    expect(lines[9].first.event).to eq(click(:nav, 7))
    expect([lines[4].first.event, lines[8].first.event]).to eq([nil, nil])
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

  it "highlights a directive's body when it's expanded, with its code blocks in their languages" do
    navigator.next_step(:down)
    navigator.next_step(:toggle)
    lines = described_class.new(navigator, width: 60, height: 14).lines
    language = lines.flatten.find { it.text.strip == 'json' }

    expect([language.style, lines.flatten.find { it.text.strip == '```' }.style]).to eq(%i[code_constant code])
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
                                       ' │ DELETE https://api.example.com/users/1          [Run] │',
                                       ' ╰───────────────────────────────────────────────────────╯',
                                       '', ' Response · json · fetched 2026-10-26', ' {}'])
      expect(lines[3].find { it.text == '[Run]' }.then { [it.event, it.style] }).to eq([click(:main, 0, :execute), :button])
      expect(lines[3].find { it.text == 'DELETE' }.style).to eq(:method_delete)
      expect(text(lines).first).to include('› DELETE api.example.com/users/1')
      expect(text(lines).drop(1).map { width(it) }).to all(eq(90))
    end
    it 'highlights its response in the language of its code block' do
      File.write(File.join(@root, 'api.md'), "<{ endpoint: }>\n```sh\ncurl https://api.example.com/users/1\n```\n" \
                                             "```json\n{\"id\": 1}\n```\n<{ :endpoint }>\n")
      navigator.next_step(:reload)
      navigator.next_step(click(:nav, navigator.content(:nav).rows.index { it.kind == :endpoint }))
      line = described_class.new(navigator, width: 90, height: 12).lines.find { |segments| segments.any? { it.text == '"id"' } }

      expect(line.filter_map { [it.text, it.style] unless it.style == :code || it.text.strip.empty? }.last(2))
        .to eq([['"id"', :code_constant], ['1', :code_number]])
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

  describe 'code feelings' do
    def main(lines) = text(lines).map { it.split('▏', 2)[1].to_s.rstrip }
    # The grid's first line, below the line above the panes, which has the batch's progress, and a blank line that leaves
    # room for the first row to be magnified.
    def grid_line(lines) = lines[3]

    # The magnified digit of the first row's cell of the method, over the blank line above it, the row's line and the
    # line below.
    def magnified(lines, index) = magnified_segments(lines, index).map { it&.text }

    # The style of the first row's cell of the method, magnified, on the blank line above it, its row and the line below.
    def magnified_style(lines, index) = magnified_segments(lines, index).map { it&.style }

    # The magnified segments in the column of the method's first cell on the first row, by its click there.
    def magnified_segments(lines, index)
      cell = lines[3].index { it.event == click(:main, index, :focus) && it.text.match?(/[█▀▄]/) }
      return [nil] * 3 unless cell

      column = lines[3].take(cell).sum { width(it.text) }
      lines[2..4].map { |line| segment_at(line, column) }
    end

    def segment_at(line, column)
      start = 0
      line.find { (start += width(it.text)) > column }
    end

    before do
      FileUtils.mkdir_p(File.join(@root, 'lib'))
      File.write(File.join(@root, 'lib', 'shapes.rb'), "class Square\n  def area\n    side * side\n  end\nend\n")
      navigator.next_step(:feelings)
      # The first draw picks the batch, as the screen draws when the view opens.
      described_class.new(navigator, width: 90, height: 24).lines
    end

    it "draws the methods as digits, the selected one on the selection's blue with its code below, then the five bins" do
      lines = described_class.new(navigator, width: 90, height: 24).lines
      main = main(lines)

      expect(text(lines).first).to include('› Code feelings')
      selected = grid_line(lines).select { it.event == click(:main, 0, :focus) }
      expect([magnified(lines, 0), selected.map(&:style).uniq]).to eq([[nil] * 3, %i[feelings_selected]])
      expect(selected.first.text).to match(/\A {0,2}\d {0,2}\z/)
      expect(main(lines)[1].strip).to eq('0% refined')
      expect(main.find { it.include?('╭─ lib/shapes.rb:2') }).to include('Square#area').and include('changed 0× ─╮')
      expect(main.find { it.include?('def area') }).to start_with(' │ def area').and end_with('│')
      expect(lines.flatten.find { it.text == 'def' }.style).to eq(:code_keyword)
      expect(main.find { it.include?('WOE') }.scan(/[A-Z]{3,}/)).to eq(%w[FROLIC NUMB WOE DREAD MALICE])
      expect(main.find { it.include?('╭─ lib/shapes.rb:2') }).not_to include('drift')
      style = ->(text) { lines.flatten.find { it.text.include?(text) }.style }
      expect(['refined', 'lib/shapes.rb:2', '02', 'NUMB'].map { style[it] }).to eq(%i[body feelings feelings feelings])
      expect(text(lines).map { width(it) }).to all(eq(90))
    end

    it 'leaves felt methods blank, but still there to select, which shows their digits on green, and their code again' do
      File.write(File.join(@root, 'lib', 'more.rb'), "def other = 1\n")
      both = Raindown::TUI::Navigator.new(root: @root).tap { it.next_step(:feelings) }
      described_class.new(both, width: 90, height: 24).lines
      felt = both.view.selected
      both.next_step(:bin2)
      both.next_step(:right)
      cell = lambda do |index|
        grid_line(described_class.new(both, width: 90, height: 24).lines).find { it.event == click(:main, index, :focus) }
      end

      expect([cell[0].text, cell[0].style, cell[0].event]).to eq([' ' * 3, :feelings, click(:main, 0, :focus)])

      both.next_step(:left)
      expect([cell[0].text, cell[0].style]).to match([/\A {0,2}\d {0,2}\z/, :felt_selected])
      expect(text(described_class.new(both, width: 90, height: 24).lines).join).to include(felt.label)
    end

    it 'rains over the pane when the batch is refined, then pops a waffle out from its butter, over balloons' do
      navigator.next_step(:bin2)
      rain = main(described_class.new(navigator, width: 90, height: 24).lines)
      expect([navigator.pace, rain.join]).to match([:animation, match(/[│╎]/)])
      expect(rain.join).not_to include('Raindown')

      Raindown::TUI::Celebration::RAIN_FRAMES.times { navigator.next_step(:tick) }
      # The waffle's rows, by its ridges' colour, which every row has, and its text, but not the balloons behind them.
      waffle = ->(line) { line.any? { it.style == :code_number || it.text.match?(/refined|mysterious/) } }
      shown = -> { described_class.new(navigator, width: 90, height: 24).lines.drop(2).count(&waffle) }
      popping = Array.new(10) { shown.call.tap { Raindown::TUI::Waffle::POP_FRAMES.times { navigator.next_step(:tick) } } }
      expect(popping).to eq([1, 3, 5, 7, 9, 11, 13, 13, 14, 15])

      lines = described_class.new(navigator, width: 90, height: 24).lines
      expect(main(lines).join).to include('█▓▓▓▓▓█', '█░░░░░█', '▄▄▄▄▄', '100% refined', 'The work is mysterious and important.')
      expect(navigator.pace).to eq(:animation)
      expect(%w[▄▄ ▄▄▄].map { |text| lines.flatten.find { it.text == text }.style }).to eq(%i[shine button])

      # Then the syrup pours onto the butter, and fills the pockets.
      40.times { navigator.next_step(:tick) }
      syrup = described_class.new(navigator, width: 90, height: 24).lines.flatten.select { it.style == :syrup }.map(&:text)
      expect(syrup).to include('│').and(include(match(/[▓░]{3,}/)))
      expect(text(lines).map { width(it) }).to all(eq(90))
    end

    it "highlights the bin of how a felt method felt, when it's selected" do
      File.write(File.join(@root, 'lib', 'more.rb'), "def other = 1\n")
      both = Raindown::TUI::Navigator.new(root: @root).tap { it.next_step(:feelings) }
      bin = ->(name) { described_class.new(both, width: 90, height: 24).lines.flatten.find { it.text.include?(name) }.style }
      expect(bin.call('MALICE')).to eq(:feelings)

      both.next_step(:bin5)
      both.next_step(:enter)
      both.next_step(:right)
      expect([bin.call('MALICE'), bin.call('NUMB')]).to eq(%i[feelings feelings])

      both.next_step(:left)
      expect([bin.call('MALICE'), bin.call('NUMB')]).to eq(%i[selected feelings])
    end

    it 'wraps a long note in as many lines as it takes, lined up after the question' do
      navigator.next_step(:bin5)
      'two negations and a hidden dependency on rows'.each_char { navigator.next_step(Raindown::TUI::Type.new(text: it)) }
      lines = described_class.new(navigator, width: 70, height: 24).lines
      note = main(lines).drop_while { !it.include?('Why MALICE?') }.take_while { !it.include?('╰') }

      expect(note).to eq([' │ Why MALICE? > two negations and a hidden │', ' │               dependency on rows▏        │'])
      expect(text(lines).map { width(it) }).to all(eq(70))
    end

    it "magnifies the digits the mouse is over, over the cells above and below them, but not when they're selected" do
      File.write(File.join(@root, 'lib', 'more.rb'), "def other = 1\n")
      both = Raindown::TUI::Navigator.new(root: @root).tap { it.next_step(:feelings) }
      described_class.new(both, width: 90, height: 24).lines
      both.next_step(Raindown::TUI::Hover.new(target: click(:main, 1, :focus)))
      lines = described_class.new(both, width: 90, height: 24).lines
      expect([magnified(lines, 0), magnified(lines, 1)]).to match([[nil] * 3, all(match(/\A[█▀▄ ]{3}\z/))])
      expect(magnified_style(lines, 1).uniq.length).to eq(1)

      both.next_step(Raindown::TUI::Hover.new(target: click(:main, 0, :focus)))
      lines = described_class.new(both, width: 90, height: 24).lines
      selected = grid_line(lines).select { it.event == click(:main, 0, :focus) }
      expect([magnified(lines, 0), selected.map(&:style).uniq]).to eq([[nil] * 3, %i[feelings_selected]])
      expect(text(lines).map { width(it) }).to all(eq(90))

      both.next_step(Raindown::TUI::Hover.new(target: nil))
      lines = described_class.new(both, width: 90, height: 24).lines
      small = grid_line(lines).find { it.event == click(:main, 1, :focus) }.text
      expect([magnified(lines, 1), small]).to match([[nil] * 3, /\A {0,2}\d {0,2}\z/])
    end

    it 'clicks the cells under a magnified digit, so the mouse over it is over them' do
      File.write(File.join(@root, 'lib', 'shapes.rb'), (1..60).map { "def m#{it} = #{it}\n" }.join)
      navigator.next_step(:reload)
      lines = described_class.new(navigator, width: 90, height: 24).lines
      columns = grid_line(lines).count { it.event&.pane == :main }

      navigator.next_step(Raindown::TUI::Hover.new(target: click(:main, 1, :focus)))
      lines = described_class.new(navigator, width: 90, height: 24).lines
      expect(magnified_segments(lines, 1).map { it.event&.index }).to eq([nil, 1, columns + 1])
    end

    it 'magnifies the digits the mouse is over in purple and lavender by turns, so neighbours stand apart' do
      File.write(File.join(@root, 'lib', 'shapes.rb'), "def short = 1\ndef long\n#{"  1\n" * 30}end\n")
      navigator.next_step(:reload)
      navigator.view.cursor = navigator.view.code_methods.index { it.name == 'short' }
      long = navigator.view.code_methods.index { it.name == 'long' }
      navigator.next_step(Raindown::TUI::Hover.new(target: click(:main, long, :focus)))
      styles = grid_line(described_class.new(navigator, width: 90, height: 24).lines).select { it.text.match?(/[█▀▄]/) }.map(&:style)

      expect([styles.length > 2, styles.each_cons(2).map(&:uniq)]).to match([true, all(contain_exactly(:feelings, :feelings_purple))])
    end

    it 'has the digits beside the method the mouse is over flee, tremble, and makes neighbouring cells bold' do
      File.write(File.join(@root, 'lib', 'shapes.rb'), (1..8).map { "def m#{it} = #{it}\n" }.join)
      navigator.next_step(:reload)
      fleeing = lambda do
        lines = Array.new(Raindown::TUI::Motion::FLEEING_TREMBLE_EVERY) do |step|
          allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return((step + 0.5) * Raindown::TUI::Motion::FLEEING_TREMBLE_SECONDS)
          grid_line(described_class.new(navigator, width: 90, height: 24).lines)
        end
        cells = ->(index) { lines.map { |line| line.find { it.event == click(:main, index, :focus) } } }
        columns = [1, 3].map { |index| cells[index].map { it.text.index(/\d/) }.uniq.sort }
        [columns, [1, 3, 4].map { |index| cells[index].map(&:style).uniq }]
      end
      fled = [[[0, 1], [1, 2]], [[:nearby], [:nearby], [:feelings]]]

      navigator.view.cursor = 7
      navigator.next_step(Raindown::TUI::Hover.new(target: click(:main, 2, :focus)))
      expect(fleeing.call).to eq(fled)

      navigator.next_step(Raindown::TUI::Hover.new(target: nil))
      navigator.view.cursor = 2
      expect(fleeing.call).to eq([[[1], [1]], [[:feelings]] * 3])
    end

    it 'keeps the digits of restless methods, the heaviest, still in the middle of their cells when the mouse is away' do
      File.write(File.join(@root, 'lib', 'shapes.rb'), "def short = 1\ndef long\n#{"  1\n" * 30}end\n")
      navigator.next_step(:reload)
      navigator.view.cursor = navigator.view.code_methods.index { it.name == 'short' }
      long = navigator.view.code_methods.index { it.name == 'long' }
      columns = Array.new(40) do |step|
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return((step + 0.5) * Raindown::TUI::Motion::FLEEING_TREMBLE_SECONDS)
        cells = grid_line(described_class.new(navigator, width: 90, height: 24).lines).select { it.event == click(:main, long, :focus) }
        cells.map { it.text.index(/\d/) }
      end

      expect([navigator.view.code_methods[long].drift, columns.flatten.uniq]).to eq([9, [1]])
    end

    it 'flickers the digits of restless methods one lower for a moment, rarely' do
      File.write(File.join(@root, 'lib', 'shapes.rb'), "def short = 1\ndef long\n#{"  1\n" * 30}end\n")
      navigator.next_step(:reload)
      navigator.view.cursor = navigator.view.code_methods.index { it.name == 'short' }
      long = navigator.view.code_methods.index { it.name == 'long' }
      digits = Array.new(Raindown::TUI::Motion::FLICKER_EVERY) do |step|
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return((step + 0.5) * Raindown::TUI::Motion::FLICKER_SECONDS)
        cells = grid_line(described_class.new(navigator, width: 90, height: 24).lines).select { it.event == click(:main, long, :focus) }
        cells.map { it.text[/\d/].to_i }
      end

      expect(digits.transpose.map { |cell| cell.tally.transform_keys { it - cell.max } }).to all(eq(0 => digits.length - 1, -1 => 1))
    end

    it 'keeps the code box as tall as it gets until expanded, so neither it nor a full grid moves as the selection does' do
      (1..300).each { File.write(File.join(@root, 'lib', "f#{it}.rb"), "def f#{it}\n#{"  1\n" * (it.odd? ? 10 : 1)}end\n") }
      fresh = Raindown::TUI::Navigator.new(root: @root).tap { it.next_step(:feelings) }
      described_class.new(fresh, width: 90, height: 24).lines
      shown = lambda do |name|
        fresh.view.cursor = fresh.view.code_methods.index { it.name == name }
        lines = described_class.new(fresh, width: 90, height: 24).lines
        [grid_line(lines).filter_map { it.event&.index }, main(lines).index { it.include?('╭─ lib/') }]
      end
      short, long = fresh.view.code_methods.partition { it.lines.length < 5 }.map { it.last.name }

      expect(shown[long]).to eq(shown[short])
    end

    it 'turns the pane red, saying the screen is too small, when the grid would be under 15 columns or 5 rows' do
      [[60, 24], [90, 20]].each do |width, height|
        pane = described_class.new(navigator, width:, height:).lines.map { |line| line.drop_while { it.text != '▏' }.drop(1) }
        middle = pane.find { |line| line.any? { it.text.include?('Screen too small.') } }

        expect([pane.drop(2).flatten.map(&:style).uniq, middle.first.text.strip]).to eq([%i[too_small], 'Screen too small.'])
      end
      expect(text(described_class.new(navigator, width: 90, height: 24).lines).join).not_to include('Screen too small.')
    end

    it 'picks the batch again to fill a resized screen, once it has kept its size for 2 seconds, keeping the selection' do
      (1..300).each { File.write(File.join(@root, 'lib', "f#{it}.rb"), "def f#{it} = #{it}\n") }
      fresh = Raindown::TUI::Navigator.new(root: @root).tap { it.next_step(:feelings) }
      draw = lambda do |seconds, width|
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(seconds)
        described_class.new(fresh, width:, height: 24).lines
        fresh.view.code_methods.length
      end
      small = draw[0, 90]
      fresh.view.cursor = 3
      selected = fresh.view.selected

      expect([draw[10, 150], draw[11.5, 150]]).to eq([small, small])
      expect(draw[12.5, 150]).to be > small
      expect(fresh.view.selected).to eq(selected)
    end

    it "shows a long method's first 6 lines, then how many more there are, clicked to show all that fit" do
      File.write(File.join(@root, 'lib', 'shapes.rb'), "class Square\n  def area\n#{(1..10).map { "    #{it}\n" }.join}  end\nend\n")
      navigator.next_step(:reload)
      box = lambda do |lines|
        main(lines).drop_while { !it.include?('╭─ lib') }.take_while { !it.include?('╰') }.drop(1).map { it.delete('│').strip }
      end
      lines = described_class.new(navigator, width: 90, height: 30).lines

      expect(box.call(lines).length).to eq(7)
      expect(box.call(lines).last(2)).to eq(['5', '[6 more lines]'])
      more = lines.flatten.find { it.text.include?('more lines') }
      expect([more.event, more.style]).to eq([click(:main, 0, :expand), :button])

      navigator.next_step(more.event)
      expect(box.call(described_class.new(navigator, width: 90, height: 30).lines).last(2)).to eq(['end', '[Fewer lines]'])
    end

    it 'wraps a long line of code in the box at spaces, carrying on at its indent after an ellipsis' do
      call = "    total = #{(1..20).map { "side#{it}" }.join(' + ')}"
      File.write(File.join(@root, 'lib', 'shapes.rb'), "class Square\n  def area\n#{call}\n  end\nend\n")
      navigator.next_step(:reload)
      lines = described_class.new(navigator, width: 90, height: 30).lines
      box = main(lines).drop_while { !it.include?('╭─ lib') }.take_while { !it.include?('╰') }.drop(1)

      code = box.map { it[3..].delete_suffix('│').delete_suffix(' ') }
      carried = code.drop(2).take_while { it.start_with?('  … ') }

      expect([code.first.rstrip, carried.length > 1]).to eq(['def area', true])
      pieces = [code[1], *carried.map { it.delete_prefix('  … ') }].map(&:rstrip)
      expect([pieces.join(' '), pieces]).to match([call.delete_prefix('  '), all(match(/(side\d+|\+)\z/))])
      expect(box.map { width(it) }.uniq).to eq([width(box.first)])
      expect(lines.flatten.find { it.text.include?('…') }.style).to eq(:feelings)
    end

    it 'asks why below the code and a line, with the bin highlighted, while the note is typed' do
      navigator.next_step(:bin4)
      'tangled'.each_char { navigator.next_step(Raindown::TUI::Type.new(text: it)) }
      lines = described_class.new(navigator, width: 90, height: 24).lines

      expect(text(lines).find { it.include?('Why DREAD?') }).to include('Why DREAD? > tangled▏')
      expect(main(lines).index { it.include?('def area') }).to be < main(lines).index { it.include?('Why DREAD?') }
      expect(main(lines)[main(lines).index { it.include?('Why DREAD?') } - 1]).to match(/\A ├─+┤\z/)
      expect(lines.flatten.find { it.text.include?('DREAD') && it.text.start_with?('│') }.style).to eq(:selected)
    end
  end
end
