# frozen_string_literal: true

require 'raindown/tui/navigator'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::Navigator do
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

  def texts(navigator, pane) = navigator.rows(pane).map(&:text)

  describe 'files pane' do
    it 'shows folders before files, each folded with Enter' do
      write('README.md')
      write('guides/setup.md')
      write('guides/deep/more.md')
      navigator = described_class.new(root: @root)

      expect(texts(navigator, :files)).to eq(['▾ guides/', '▾ deep/', 'more.md', 'setup.md', 'README.md'])
      expect(navigator.rows(:files).map(&:depth)).to eq([0, 1, 2, 1, 0])

      navigator.handle(:enter)
      expect(texts(navigator, :files)).to eq(['▸ guides/', 'README.md'])
    end

    it 'opens the first file, and a file chosen with Enter, which moves to the outline' do
      write('a.md', "# A\n")
      write('b.md', "# B\n")
      navigator = described_class.new(root: @root)
      expect(navigator.relative(navigator.path)).to eq('a.md')

      navigator.handle(:down)
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
        [[], [['[+2]', :toggle]], [], [['[+3]', :toggle], ['[Run]', :execute]], []]
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

    it 'folds the section below a heading' do
      navigator.handle(:toggle)

      expect(texts(navigator, :outline)).to eq(['# Notes …', '# Usage'])
    end

    it 'runs the selected endpoint while showing a message, then reads the file again' do
      allow(Raindown::Curl).to receive(:run).and_return(['{ "id": 1 }', 'json'])
      3.times { navigator.handle(:down) }

      effect = navigator.handle(:execute)
      expect(effect.first(2)).to eq([:wait, 'Running the endpoint on line 14...'])

      effect.last.call
      expect(File.read(navigator.path)).to include('{ "id": 1 }')
      expect(navigator.status).to eq([:info, 'Ran the endpoint on line 14'])
    end

    it 'runs an endpoint when its button is pressed' do
      allow(Raindown::Curl).to receive(:run).and_return(['{ "id": 1 }', 'json'])

      navigator.handle([:press, :outline, 3, :execute]).last.call

      expect(File.read(navigator.path)).to include('{ "id": 1 }')
    end

    it "shows an error for something that isn't an endpoint" do
      expect(navigator.handle(:execute)).to be_nil
      expect(navigator.status).to eq([:error, 'Select an endpoint to run'])
    end

    it 'opens the editor at the selected line, then writes back the file' do
      2.times { navigator.handle(:down) }

      expect(navigator.handle(:edit)).to eq([:run, Raindown::Actions.edit_command(navigator.path, line: 10)])

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

  describe '#visible' do
    it 'scrolls so the cursor is in view' do
      10.times { write("#{it}.md") }
      navigator = described_class.new(root: @root)
      6.times { navigator.handle(:down) }

      rows, offset = navigator.visible(:files, 3)
      expect([rows.map(&:text), offset]).to eq([%w[4.md 5.md 6.md], 4])

      5.times { navigator.handle(:up) }
      expect(navigator.visible(:files, 3).last).to eq(1)
    end
  end
end
