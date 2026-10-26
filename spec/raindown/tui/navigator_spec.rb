# frozen_string_literal: true

require 'raindown/tui/navigator'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::Navigator do
  def click(pane, index, action = :enter) = Raindown::TUI::Click.new(pane:, index:, action:)

  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      FileUtils.mkdir_p(File.join(@root, '.raindown'))
      example.run
    end
  end

  let(:curl) { "```sh\ncurl https://api.example.com\n```\n" }
  let(:notes) do
    "# Notes\n\n<{ toc: }>\n\n- [Notes](#notes)\n- [Setup](#setup)\n\n<{ :toc }>\n\n## Setup\n\nText.\n\n" \
      "<{ endpoint: }>\n\n#{curl}\n```json\n{}\n```\n<{ :endpoint }>\n\n# Usage\n"
  end

  def write(name, content = "# #{name}\n")
    File.join(@root, name).tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end

  # The rows that can be selected, without the separator between the Dashboard and the files.
  def texts(navigator, pane) = navigator.rows(pane).select(&:selectable?).map(&:text)

  describe 'files pane' do
    it 'starts on the Dashboard, above folders and files, with the folders folded until Enter opens them' do
      write('README.md')
      write('guides/setup.md')
      write('guides/deep/more.md')
      navigator = described_class.new(root: @root)

      expect([navigator.view, navigator.focus, navigator.cursor(:files)]).to eq([:dashboard, :files, 0])
      expect(texts(navigator, :files)).to eq(['📊 Dashboard', '▸ guides/', 'README.md'])

      navigator.handle(:down)
      navigator.handle(:enter)
      expect(texts(navigator, :files)).to eq(['📊 Dashboard', '▾ guides/', '▸ deep/', 'setup.md', 'README.md'])
      expect(navigator.rows(:files).select(&:selectable?).map(&:depth)).to eq([0, 0, 1, 1, 0])
    end

    it "marks the projects inside the folder with Raindown's cloud, which fold like folders" do
      write('guides/setup.md')
      FileUtils.mkdir_p(File.join(@root, 'guides', '.raindown'))
      navigator = described_class.new(root: @root)

      expect(navigator.rows(:files).select(&:selectable?).map { [it.kind, it.text] })
        .to eq([[:dashboard, '📊 Dashboard'], [:project, '▸ 🌧 guides/']])

      navigator.handle(:down)
      navigator.handle(:enter)
      expect(texts(navigator, :files)).to eq(['📊 Dashboard', '▾ 🌧 guides/', 'setup.md'])
    end

    it 'opens a file asked for, in its open folder' do
      navigator = described_class.new(root: @root, path: write('guides/deep/more.md'))

      expect([navigator.view, navigator.relative(navigator.path)]).to eq([:browser, 'guides/deep/more.md'])
      expect(texts(navigator, :files)).to eq(['📊 Dashboard', '▾ guides/', '▾ deep/', 'more.md'])
      expect(navigator.cursor(:files)).to eq(4)
    end

    it 'opens a file chosen with Enter, which moves to the outline' do
      write('a.md', "# A\n")
      write('b.md', "# B\n")
      navigator = described_class.new(root: @root)

      2.times { navigator.handle(:down) }
      navigator.handle(:enter)

      expect(navigator.relative(navigator.path)).to eq('b.md')
      expect(navigator.focus).to eq(:outline)
      expect(texts(navigator, :outline)).to eq(['# B'])
    end
  end

  describe 'outline pane' do
    subject(:navigator) { described_class.new(root: @root, path: write('notes.md', notes)) }

    before { navigator.handle(:right) }

    it "shows headings and directives, without the headings a directive's output holds" do
      expect(texts(navigator, :outline)).to eq(['# Notes', 'toc:', '## Setup', 'endpoint:', '# Usage'])
      expect(navigator.rows(:outline).map(&:depth)).to eq([0, 1, 1, 2, 0])
      expect(navigator.rows(:outline).map(&:buttons)).to eq(
        [[], [['[+2]', :toggle]], [], [['[+7]', :toggle], ['[Run]', :execute]], []]
      )
    end

    it "expands a directive's output with Enter, and contracts it again" do
      navigator.handle(:down)
      navigator.handle(:enter)

      expect(texts(navigator, :outline)[1..3]).to eq(['toc:', '- [Notes](#notes)', '- [Setup](#setup)'])
      expect(navigator.rows(:outline)[1].buttons.first).to eq(['[-]', :toggle])

      navigator.handle(:enter)
      expect(texts(navigator, :outline)[2]).to eq('## Setup')
    end

    it "expands an endpoint to its request and response, even before it's run" do
      3.times { navigator.handle(:down) }
      navigator.handle(:enter)

      expect(texts(navigator, :outline)[4..]).to eq(
        ['```sh', 'curl https://api.example.com', '```', '', '```json', '{}', '```', '# Usage']
      )

      File.write(navigator.path, "<{ endpoint: }>\n#{curl}<{ :endpoint }>\n")
      navigator.handle(:reload)
      navigator.handle(:up)
      navigator.handle(:enter)
      expect(texts(navigator, :outline)).to eq(['endpoint:', '```sh', 'curl https://api.example.com', '```'])
    end

    it 'folds the section below a heading' do
      navigator.handle(:toggle)

      expect(texts(navigator, :outline)).to eq(['# Notes …', '# Usage'])
    end

    it 'runs the selected endpoint while showing a message, then reads the file again' do
      allow(Raindown::Curl).to receive(:run).and_return(['{ "id": 1 }', 'json'])
      3.times { navigator.handle(:down) }

      effect = navigator.handle(:execute)
      expect(effect.message).to eq('Running the endpoint on line 14...')

      effect.task.call
      expect(File.read(navigator.path)).to include('{ "id": 1 }')
      expect(navigator.status).to eq([:info, 'Ran the endpoint on line 14'])
    end

    it 'runs an endpoint when its button is pressed' do
      allow(Raindown::Curl).to receive(:run).and_return(['{ "id": 1 }', 'json'])

      navigator.handle(click(:outline, 3, :execute)).task.call

      expect(File.read(navigator.path)).to include('{ "id": 1 }')
    end

    it "shows an error for something that isn't an endpoint" do
      expect(navigator.handle(:execute)).to be_nil
      expect(navigator.status).to eq([:error, 'Select an endpoint to run'])
    end

    it 'opens the editor at the selected line, then writes back the file' do
      2.times { navigator.handle(:down) }

      expect(navigator.handle(:edit)).to eq(Raindown::TUI::Run.new(command: Raindown::Actions.edit_command(navigator.path, line: 10)))

      File.write(navigator.path, "# Notes\n\n<{ toc: }>\n<{ :toc }>\n\n## Added\n")
      navigator.ran
      expect(File.read(navigator.path)).to include('- [Added](#added)')
      expect(navigator.status).to eq([:info, 'Updated notes.md'])
    end

    it 'reads the file again when it changes' do
      File.write(navigator.path, "# Changed\n")
      File.utime(Time.now + 5, Time.now + 5, navigator.path)

      navigator.handle(:tick)
      expect(texts(navigator, :outline)).to eq(['# Changed'])
    end

    it 'shows an error in the file in place of the outline' do
      File.write(navigator.path, "<{ toc: }>\n")
      navigator.handle(:reload)

      expect(navigator.rows(:outline).map { [it.kind, it.text] }).to eq([[:error, '<{ toc: }> on line 1 needs <{ :toc }>']])
    end
  end

  describe 'clicks' do
    it 'do what Enter does in the files: open the Dashboard, fold a folder, open a file' do
      write('guides/setup.md', "# Setup\n")
      write('notes.md', "# Notes\n")
      navigator = described_class.new(root: @root, path: File.join(@root, 'notes.md'))

      navigator.handle(click(:files, 2))
      expect(texts(navigator, :files)).to eq(['📊 Dashboard', '▾ guides/', 'setup.md', 'notes.md'])

      navigator.handle(click(:files, 3))
      expect([navigator.view, navigator.relative(navigator.path), navigator.focus]).to eq([:browser, 'guides/setup.md', :outline])

      navigator.handle(click(:files, 0))
      expect(navigator.view).to eq(:dashboard)
    end

    it "open a dashboard's chart, wherever it's clicked" do
      write('stats.md', "# Stats\n\n<{ chart: '1 2 3' }>\n<{ :chart }>\n")
      navigator = described_class.new(root: @root)

      navigator.handle(click(:dashboard, 0))
      expect([navigator.view, navigator.relative(navigator.path), navigator.cursor(:outline)]).to eq([:browser, 'stats.md', 1])
    end

    it 'do what Enter does, unless that would leave the terminal UI, like for the editor, so they only move the cursor' do
      navigator = described_class.new(root: @root, path: write('notes.md', notes))
      navigator.handle(click(:outline, 1))
      navigator.handle(:down)
      expect(navigator.handle(:enter)).to eq(Raindown::TUI::Run.new(command: Raindown::Actions.edit_command(navigator.path, line: 5)))

      expect(navigator.handle(click(:outline, 3))).to be_nil
      expect(navigator.cursor(:outline)).to eq(3)
    end

    it 'fold headings and directives in the outline, and only select their other lines, without opening the editor' do
      navigator = described_class.new(root: @root, path: write('notes.md', notes))

      navigator.handle(click(:outline, 1))
      expect(texts(navigator, :outline)[1..3]).to eq(['toc:', '- [Notes](#notes)', '- [Setup](#setup)'])

      expect(navigator.handle(click(:outline, 2))).to be_nil
      expect([navigator.focus, navigator.cursor(:outline)]).to eq([:outline, 2])

      navigator.handle(click(:outline, 0))
      expect(texts(navigator, :outline)).to eq(['# Notes …', '# Usage'])
    end
  end

  describe '#visible' do
    it 'scrolls so the cursor is in view' do
      10.times { write("#{it}.md") }
      navigator = described_class.new(root: @root)
      6.times { navigator.handle(:down) }

      rows, offset = navigator.visible(:files, 3)
      expect([rows.map(&:text), offset]).to eq([%w[3.md 4.md 5.md], 5])

      5.times { navigator.handle(:up) }
      expect(navigator.visible(:files, 3).last).to eq(2)
      navigator.handle(:up)
      expect(navigator.cursor(:files)).to eq(0)
    end
  end

  describe 'dashboard' do
    subject(:navigator) { described_class.new(root: @root, path: write('notes.md', notes)) }

    before do
      write('stats.md', "# Stats\n\n## Downloads\n\n<{ chart: '1 2 3' }>\n<{ :chart }>\n")
      navigator.handle(:dashboard)
    end

    it 'switches to the dashboard of charts, with the cursor on it in the files, and back to the open file with d' do
      expect([navigator.view, navigator.focus, navigator.cursor(:files)]).to eq([:dashboard, :files, 0])
      expect(navigator.status).to eq([:info, "1 chart in #{File.basename(@root)}"])

      navigator.handle(:dashboard)
      expect([navigator.view, navigator.relative(navigator.path)]).to eq([:browser, 'notes.md'])
    end

    it 'opens the dashboard from the top of the files, beside them, and a file from the files again' do
      navigator.handle(:dashboard)
      navigator.handle(:left)
      5.times { navigator.handle(:up) }
      navigator.handle(:enter)
      expect([navigator.view, navigator.focus]).to eq(%i[dashboard files])

      navigator.handle(:tab)
      expect(navigator.focus).to eq(:dashboard)
      navigator.handle(:tab)
      expect(navigator.focus).to eq(:files)
      navigator.handle(:right)
      expect(navigator.focus).to eq(:dashboard)

      navigator.handle(click(:files, 3))
      navigator.handle(:enter)
      expect([navigator.view, navigator.relative(navigator.path)]).to eq([:browser, 'stats.md'])
    end

    it "doesn't edit the Dashboard as a file" do
      expect(navigator.handle(:edit)).to be_nil
      expect(navigator.status).to eq([:error, 'Select a file to edit'])
    end

    it 'goes back to the files with left from the first card in a row, and otherwise moves along the cards' do
      write('more.md', "<{ chart: '3 2 1' }>\n<{ :chart }>\n")
      navigator.handle(:reload)
      navigator.handle(:right)
      navigator.dashboard.rows = [[0, 1]]

      navigator.handle(:right)
      navigator.handle(:left)
      expect([navigator.focus, navigator.dashboard.cursor]).to eq([:dashboard, 0])

      navigator.handle(:left)
      expect(navigator.focus).to eq(:files)
    end

    it "opens a chart's file in the outline, on its directive" do
      navigator.handle(:right)
      navigator.handle(:enter)

      expect([navigator.view, navigator.focus, navigator.relative(navigator.path)]).to eq([:browser, :outline, 'stats.md'])
      expect(navigator.rows(:outline)[navigator.cursor(:outline)].text).to eq("chart: '1 2 3'")
      expect(navigator.rows(:files)[navigator.cursor(:files)].text).to eq('stats.md')
    end

    it "edits a chart's file at its directive, then writes back to it" do
      navigator.handle(:right)

      command = Raindown::Actions.edit_command(File.join(@root, 'stats.md'), line: 5)
      expect(navigator.handle(:edit)).to eq(Raindown::TUI::Run.new(command:))

      navigator.ran
      expect(File.read(File.join(@root, 'stats.md'))).to include('▁▅█')
    end
  end

  describe 'project menu' do
    subject(:navigator) { described_class.new(root: @root) }

    before do
      write('notes.md', "<{ chart: '1 2 3' }>\n<{ :chart }>\n")
      write('guides/setup.md', "<{ chart: '3 2 1' }>\n<{ :chart }>\n")
      FileUtils.mkdir_p(File.join(@root, 'guides', '.raindown'))
    end

    it 'lists every project, and narrows the files and dashboard to the one chosen' do
      navigator.handle(:projects)
      expect([navigator.menu, navigator.menu_items]).to eq([0, [nil, @root, File.join(@root, 'guides')]])

      2.times { navigator.handle(:down) }
      navigator.handle(:enter)

      expect([navigator.menu, navigator.project, navigator.view]).to eq([nil, File.join(@root, 'guides'), :dashboard])
      expect(texts(navigator, :files)).to eq(['📊 Dashboard', 'setup.md'])
      expect(navigator.dashboard.charts.map { File.basename(it.path) }).to eq(['setup.md'])
      expect(navigator.status).to eq([:info, '1 chart in guides'])
    end

    it "shows a project's own files, without the projects inside it, and every project's again with All projects" do
      navigator.handle(:projects)
      navigator.handle(click(:menu, 1))
      expect(texts(navigator, :files)).to eq(['📊 Dashboard', 'notes.md'])

      navigator.handle(:projects)
      expect(navigator.menu).to eq(1)
      navigator.handle(click(:menu, 0))
      expect(texts(navigator, :files)).to eq(['📊 Dashboard', '▸ 🌧 guides/', 'notes.md'])
      expect(navigator.dashboard.charts.length).to eq(2)
    end

    it 'stays open until a project is chosen with Enter or a click, while other events do nothing' do
      navigator.handle(:projects)
      [:down, click(:files, 1), click(:dashboard, 0), nil, :tick, :tab, :edit].each do |event|
        navigator.handle(event)
      end
      expect([navigator.menu, navigator.project, navigator.focus]).to eq([1, nil, :files])

      navigator.handle(:enter)
      expect([navigator.menu, navigator.project]).to eq([nil, @root])

      navigator.handle(:projects)
      navigator.handle(click(:menu, 2))
      expect([navigator.menu, navigator.project]).to eq([nil, File.join(@root, 'guides')])
    end

    it 'closes with Esc or p, without choosing' do
      %i[escape projects].each do |event|
        navigator.handle(:projects)
        navigator.handle(:down)
        navigator.handle(event)
        expect([navigator.menu, navigator.project]).to eq([nil, nil])
      end
    end

    it "doesn't open with one project" do
      FileUtils.rm_rf(File.join(@root, 'guides', '.raindown'))
      navigator = described_class.new(root: @root)

      navigator.handle(:projects)
      expect([navigator.menu, navigator.status]).to eq([nil, [:info, "There's one project here"]])
    end
  end
end
