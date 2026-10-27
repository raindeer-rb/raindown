# frozen_string_literal: true

require 'raindown/tui/navigator/navigator'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::Navigator do
  def click(pane, index, action = :enter) = Raindown::TUI::Click.new(pane:, index:, action:)
  def view_name(navigator) = navigator.view.class.name.delete_prefix('Raindown::TUI::')

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
  def texts(navigator, pane) = navigator.content(pane).rows.select(&:selectable?).map(&:text)

  describe 'nav pane' do
    it 'starts on the Dashboard, above folders and files, with the folders folded until Enter opens them' do
      write('README.md')
      write('guides/setup.md')
      write('guides/deep/more.md')
      navigator = described_class.new(root: @root)

      expect([view_name(navigator), navigator.focus, navigator.content(:nav).cursor]).to eq(['DashboardView', :main, 0])
      expect(texts(navigator, :nav)).to eq(['📊 Dashboard', '▸ guides/', 'README.md'])

      navigator.next_step(:left)
      navigator.next_step(:down)
      navigator.next_step(:enter)
      expect(texts(navigator, :nav)).to eq(['📊 Dashboard', '▾ guides/', '▸ deep/', 'setup.md', 'README.md'])
      expect(navigator.content(:nav).rows.select(&:selectable?).map(&:depth)).to eq([0, 0, 1, 1, 0])
    end

    it "marks the projects inside the folder with Raindown's cloud, which fold like folders" do
      write('guides/setup.md')
      FileUtils.mkdir_p(File.join(@root, 'guides', '.raindown'))
      navigator = described_class.new(root: @root)

      expect(navigator.content(:nav).rows.select(&:selectable?).map { [it.kind, it.text] })
        .to eq([[:dashboard, '📊 Dashboard'], [:project, '▸ 🌧 guides/']])

      navigator.next_step(:left)
      navigator.next_step(:down)
      navigator.next_step(:enter)
      expect(texts(navigator, :nav)).to eq(['📊 Dashboard', '▾ 🌧 guides/', 'setup.md'])
    end

    it 'opens a file asked for, in its open folder' do
      navigator = described_class.new(root: @root, path: write('guides/deep/more.md'))

      expect([view_name(navigator), navigator.relative(navigator.path)]).to eq(['OutlineView', 'guides/deep/more.md'])
      expect(texts(navigator, :nav)).to eq(['📊 Dashboard', '▾ guides/', '▾ deep/', 'more.md'])
      expect(navigator.content(:nav).cursor).to eq(4)
    end

    it 'opens a file chosen with Enter, which moves to the outline' do
      write('a.md', "# A\n")
      write('b.md', "# B\n")
      navigator = described_class.new(root: @root)

      navigator.next_step(:left)
      2.times { navigator.next_step(:down) }
      navigator.next_step(:enter)

      expect(navigator.relative(navigator.path)).to eq('b.md')
      expect(navigator.focus).to eq(:main)
      expect(texts(navigator, :main)).to eq(['# B'])
    end
  end

  describe 'outline' do
    subject(:navigator) { described_class.new(root: @root, path: write('notes.md', notes)) }

    before { navigator.next_step(:right) }

    it "shows headings and directives, without the headings a directive's output holds" do
      expect(texts(navigator, :main)).to eq(['# Notes', 'toc:', '## Setup', 'endpoint:', '# Usage'])
      expect(navigator.view.rows.map(&:depth)).to eq([0, 1, 1, 2, 0])
      expect(navigator.view.rows.map(&:buttons)).to eq(
        [[], [['[+2]', :toggle]], [], [['[+7]', :toggle], ['[Run]', :execute]], []]
      )
    end

    it "expands a directive's output with Enter, and contracts it again" do
      navigator.next_step(:down)
      navigator.next_step(:enter)

      expect(texts(navigator, :main)[1..3]).to eq(['toc:', '- [Notes](#notes)', '- [Setup](#setup)'])
      expect(navigator.view.rows[1].buttons.first).to eq(['[-]', :toggle])

      navigator.next_step(:enter)
      expect(texts(navigator, :main)[2]).to eq('## Setup')
    end

    it "expands an endpoint to its request and response, even before it's run" do
      3.times { navigator.next_step(:down) }
      navigator.next_step(:enter)

      expect(texts(navigator, :main)[4..]).to eq(
        ['```sh', 'curl https://api.example.com', '```', '', '```json', '{}', '```', '# Usage']
      )

      File.write(navigator.path, "<{ endpoint: }>\n#{curl}<{ :endpoint }>\n")
      navigator.next_step(:reload)
      navigator.next_step(:up)
      navigator.next_step(:enter)
      expect(texts(navigator, :main)).to eq(['endpoint:', '```sh', 'curl https://api.example.com', '```'])
    end

    it 'folds the section below a heading' do
      navigator.next_step(:toggle)

      expect(texts(navigator, :main)).to eq(['# Notes …', '# Usage'])
    end

    it 'runs the selected endpoint while showing a message, then reads the file again' do
      allow(Raindown::Curl).to receive(:run).and_return(['{ "id": 1 }', 'json'])
      3.times { navigator.next_step(:down) }

      effect = navigator.next_step(:execute)
      expect(effect.message).to eq('Running the endpoint on line 14...')

      effect.task.call
      expect(File.read(navigator.path)).to include('{ "id": 1 }')
      expect(navigator.status).to eq([:info, 'Ran the endpoint on line 14'])
    end

    it 'runs an endpoint when its button is pressed' do
      allow(Raindown::Curl).to receive(:run).and_return(['{ "id": 1 }', 'json'])

      navigator.next_step(click(:main, 3, :execute)).task.call

      expect(File.read(navigator.path)).to include('{ "id": 1 }')
    end

    it "shows an error for something that isn't an endpoint" do
      expect(navigator.next_step(:execute)).to be_nil
      expect(navigator.status).to eq([:error, 'Select an endpoint to run'])
    end

    it 'opens the editor at the selected line, then writes back the file' do
      2.times { navigator.next_step(:down) }

      expect(navigator.next_step(:edit)).to eq(Raindown::TUI::Run.new(command: Raindown::Actions.edit_command(navigator.path, line: 10)))

      File.write(navigator.path, "# Notes\n\n<{ toc: }>\n<{ :toc }>\n\n## Added\n")
      navigator.ran
      expect(File.read(navigator.path)).to include('- [Added](#added)')
      expect(navigator.status).to eq([:info, 'Updated notes.md'])
    end

    it 'reads the file again when it changes' do
      File.write(navigator.path, "# Changed\n")
      File.utime(Time.now + 5, Time.now + 5, navigator.path)

      navigator.next_step(:tick)
      expect(texts(navigator, :main)).to eq(['# Changed'])
    end

    it 'shows an error in the file in place of the outline' do
      File.write(navigator.path, "<{ toc: }>\n")
      navigator.next_step(:reload)

      expect(navigator.view.rows.map { [it.kind, it.text] }).to eq([[:error, '<{ toc: }> on line 1 needs <{ :toc }>']])
    end
  end

  describe 'clicks' do
    it 'do what Enter does in the files: open the Dashboard, fold a folder, open a file' do
      write('guides/setup.md', "# Setup\n")
      write('notes.md', "# Notes\n")
      navigator = described_class.new(root: @root, path: File.join(@root, 'notes.md'))

      navigator.next_step(click(:nav, 2))
      expect(texts(navigator, :nav)).to eq(['📊 Dashboard', '▾ guides/', 'setup.md', 'notes.md'])

      navigator.next_step(click(:nav, 3))
      expect([view_name(navigator), navigator.relative(navigator.path), navigator.focus]).to eq(['OutlineView', 'guides/setup.md', :main])

      navigator.next_step(click(:nav, 0))
      expect(view_name(navigator)).to eq('DashboardView')
    end

    it "open a dashboard's chart, wherever it's clicked" do
      write('stats.md', "# Stats\n\n<{ chart: '1 2 3' }>\n<{ :chart }>\n")
      navigator = described_class.new(root: @root)

      navigator.next_step(click(:main, 0))
      expect([view_name(navigator), navigator.relative(navigator.path), navigator.view.cursor]).to eq(['OutlineView', 'stats.md', 1])
    end

    it 'do what Enter does, unless that would leave the terminal UI, like for the editor, so they only move the cursor' do
      navigator = described_class.new(root: @root, path: write('notes.md', notes))
      navigator.next_step(click(:main, 1))
      navigator.next_step(:down)
      expect(navigator.next_step(:enter)).to eq(Raindown::TUI::Run.new(command: Raindown::Actions.edit_command(navigator.path, line: 5)))

      expect(navigator.next_step(click(:main, 3))).to be_nil
      expect(navigator.view.cursor).to eq(3)
    end

    it 'fold headings and directives in the outline, and only select their other lines, without opening the editor' do
      navigator = described_class.new(root: @root, path: write('notes.md', notes))

      navigator.next_step(click(:main, 1))
      expect(texts(navigator, :main)[1..3]).to eq(['toc:', '- [Notes](#notes)', '- [Setup](#setup)'])

      expect(navigator.next_step(click(:main, 2))).to be_nil
      expect([navigator.focus, navigator.view.cursor]).to eq([:main, 2])

      navigator.next_step(click(:main, 0))
      expect(texts(navigator, :main)).to eq(['# Notes …', '# Usage'])
    end
  end

  describe '#visible' do
    it 'scrolls so the cursor is in view' do
      10.times { write("#{it}.md") }
      navigator = described_class.new(root: @root)
      navigator.next_step(:left)
      6.times { navigator.next_step(:down) }

      rows, offset = navigator.content(:nav).visible(3)
      expect([rows.map(&:text), offset]).to eq([%w[3.md 4.md 5.md], 5])

      5.times { navigator.next_step(:up) }
      expect(navigator.content(:nav).visible(3).last).to eq(2)
      navigator.next_step(:up)
      expect(navigator.content(:nav).cursor).to eq(0)
    end
  end

  describe 'dashboard' do
    subject(:navigator) { described_class.new(root: @root, path: write('notes.md', notes)) }

    before do
      write('stats.md', "# Stats\n\n## Downloads\n\n<{ chart: '1 2 3' }>\n<{ :chart }>\n")
      navigator.next_step(:dashboard)
    end

    it 'switches to the dashboard of charts, with the cursor on it in the files, and back to the open file with d' do
      expect([view_name(navigator), navigator.focus, navigator.content(:nav).cursor]).to eq(['DashboardView', :main, 0])
      expect(navigator.status).to eq([:info, "1 chart in #{File.basename(@root)}"])

      navigator.next_step(:dashboard)
      expect([view_name(navigator), navigator.relative(navigator.path)]).to eq(['OutlineView', 'notes.md'])
    end

    it 'opens the dashboard from the top of the files, beside them, and a file from the files again' do
      navigator.next_step(:dashboard)
      navigator.next_step(:left)
      5.times { navigator.next_step(:up) }
      navigator.next_step(:enter)
      expect([view_name(navigator), navigator.focus]).to eq(['DashboardView', :main])

      navigator.next_step(:tab)
      expect(navigator.focus).to eq(:nav)
      navigator.next_step(:right)
      expect(navigator.focus).to eq(:main)

      navigator.next_step(click(:nav, 3))
      navigator.next_step(:enter)
      expect([view_name(navigator), navigator.relative(navigator.path)]).to eq(['OutlineView', 'stats.md'])
    end

    it "doesn't edit the Dashboard as a file" do
      navigator.next_step(:left)
      expect(navigator.next_step(:edit)).to be_nil
      expect(navigator.status).to eq([:error, 'Select a file to edit'])
    end

    it 'goes back to the files with left from the first card in a row, and otherwise moves along the cards' do
      write('more.md', "<{ chart: '3 2 1' }>\n<{ :chart }>\n")
      navigator.next_step(:reload)
      navigator.next_step(:right)
      navigator.dashboard.rows(59)

      navigator.next_step(:right)
      navigator.next_step(:left)
      expect([navigator.focus, navigator.dashboard.cursor]).to eq([:main, 0])

      navigator.next_step(:left)
      expect(navigator.focus).to eq(:nav)
    end

    it "opens a chart's file in the outline, on its directive" do
      navigator.next_step(:right)
      navigator.next_step(:enter)

      expect([view_name(navigator), navigator.focus, navigator.relative(navigator.path)]).to eq(['OutlineView', :main, 'stats.md'])
      expect(navigator.view.rows[navigator.view.cursor].text).to eq("chart: '1 2 3'")
      expect(navigator.content(:nav).rows[navigator.content(:nav).cursor].text).to eq('stats.md')
    end

    it "edits a chart's file at its directive, then writes back to it" do
      navigator.next_step(:right)

      command = Raindown::Actions.edit_command(File.join(@root, 'stats.md'), line: 5)
      expect(navigator.next_step(:edit)).to eq(Raindown::TUI::Run.new(command:))

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
      navigator.next_step(:projects)
      expect([navigator.menu, navigator.menu_items]).to eq([0, [nil, @root, File.join(@root, 'guides')]])

      2.times { navigator.next_step(:down) }
      navigator.next_step(:enter)

      expect([navigator.menu, navigator.project, view_name(navigator)]).to eq([nil, File.join(@root, 'guides'), 'DashboardView'])
      expect(texts(navigator, :nav)).to eq(['📊 Dashboard', 'setup.md'])
      expect(navigator.dashboard.charts.map { File.basename(it.path) }).to eq(['setup.md'])
      expect(navigator.status).to eq([:info, '1 chart in guides'])
    end

    it "shows a project's own files, without the projects inside it, and every project's again with All projects" do
      navigator.next_step(:projects)
      navigator.next_step(click(:menu, 1))
      expect(texts(navigator, :nav)).to eq(['📊 Dashboard', 'notes.md'])

      navigator.next_step(:projects)
      expect(navigator.menu).to eq(1)
      navigator.next_step(click(:menu, 0))
      expect(texts(navigator, :nav)).to eq(['📊 Dashboard', '▸ 🌧 guides/', 'notes.md'])
      expect(navigator.dashboard.charts.length).to eq(2)
    end

    it 'stays open until a project is chosen with Enter or a click, while other events do nothing' do
      navigator.next_step(:projects)
      [:down, click(:nav, 1), click(:main, 0), nil, :tick, :tab, :edit].each do |event|
        navigator.next_step(event)
      end
      expect([navigator.menu, navigator.project, navigator.focus]).to eq([1, nil, :main])

      navigator.next_step(:enter)
      expect([navigator.menu, navigator.project]).to eq([nil, @root])

      navigator.next_step(:projects)
      navigator.next_step(click(:menu, 2))
      expect([navigator.menu, navigator.project]).to eq([nil, File.join(@root, 'guides')])
    end

    it 'closes with Esc or p, without choosing' do
      %i[escape projects].each do |event|
        navigator.next_step(:projects)
        navigator.next_step(:down)
        navigator.next_step(event)
        expect([navigator.menu, navigator.project]).to eq([nil, nil])
      end
    end

    it "doesn't open with one project" do
      FileUtils.rm_rf(File.join(@root, 'guides', '.raindown'))
      navigator = described_class.new(root: @root)

      navigator.next_step(:projects)
      expect([navigator.menu, navigator.status]).to eq([nil, [:info, "There's one project here"]])
    end
  end

  describe 'endpoints' do
    subject(:navigator) { described_class.new(root: @root) }

    before do
      write('a.md', "# A\n")
      post = "<{ endpoint: }>\n```sh\ncurl -X POST https://api.example.com/users\n```\n<{ :endpoint }>\n"
      write('api.md', "# API\n\n<{ endpoint: }>\n#{curl}<{ :endpoint }>\n\n#{post}")
    end

    def endpoints(navigator) = navigator.content(:nav).rows.select { it.kind == :endpoint }.map { it.target.text }

    it 'lists every endpoint below the files, after a blank line, by its request, with its method in its colour' do
      expect(navigator.content(:nav).rows.last(3).map { [it.kind, it.tag&.then { [it.method, it.style] }, it.text] })
        .to eq([[:separator, nil, ''], [:endpoint, ['GET', :method_get], 'api.example.com'],
                [:endpoint, ['POST', :method_post], 'api.example.com/users']])
    end

    it 'scrolls with the files, and the cursor moves from the last file to the first endpoint and back' do
      navigator.next_step(:left)
      3.times { navigator.next_step(:down) }
      expect(navigator.content(:nav).rows[navigator.content(:nav).cursor].text).to eq('api.example.com')

      navigator.next_step(:up)
      expect(navigator.content(:nav).rows[navigator.content(:nav).cursor].text).to eq('api.md')
    end

    it 'opens an endpoint beside the files, with its response, and its directive in the outline with Enter' do
      navigator.next_step(click(:nav, 6))
      expect([view_name(navigator), navigator.view.endpoint.line, navigator.focus]).to eq(['EndpointView', 9, :main])
      expect(navigator.view.response).to eq([])

      navigator.next_step(:enter)
      expect([view_name(navigator), navigator.relative(navigator.path), navigator.focus]).to eq(['OutlineView', 'api.md', :main])
      expect(navigator.view.rows[navigator.view.cursor].target.line).to eq(9)
    end

    it 'runs an opened endpoint with X' do
      allow(Raindown::Curl).to receive(:run).and_return(['{}', 'json'])
      navigator.next_step(click(:nav, 6))

      navigator.next_step(:execute).task.call
      expect(navigator.view.response).to eq(['{}'])
    end

    it 'runs an opened endpoint with its button, and shows the response' do
      allow(Raindown::Curl).to receive(:run).and_return(["{\n  \"id\": 1\n}", 'json'])
      navigator.next_step(click(:nav, 5))

      navigator.next_step(click(:main, 0, :execute)).task.call
      view = navigator.view
      expect([view.language, view.response, view.fetched]).to eq(['json', ['{', '  "id": 1', '}'], Date.today.iso8601])
    end

    it 'runs the selected endpoint' do
      allow(Raindown::Curl).to receive(:run).and_return(['{ "id": 1 }', 'json'])
      navigator.next_step(:left)
      3.times { navigator.next_step(:down) }

      effect = navigator.next_step(:execute)
      expect(effect.message).to eq('Running GET api.example.com...')
      effect.task.call
      expect(File.read(File.join(@root, 'api.md'))).to include('{ "id": 1 }')
    end

    it 'narrows to the project chosen in the menu, and shows its own' do
      write('guides/more.md', "<{ endpoint: }>\n```sh\ncurl https://guides.example.com\n```\n<{ :endpoint }>\n")
      FileUtils.mkdir_p(File.join(@root, 'guides', '.raindown'))
      navigator = described_class.new(root: @root)
      expect(endpoints(navigator).length).to eq(3)

      navigator.next_step(:projects)
      navigator.next_step(click(:menu, 2))
      expect(endpoints(navigator)).to eq(['GET guides.example.com'])
    end
  end
end
