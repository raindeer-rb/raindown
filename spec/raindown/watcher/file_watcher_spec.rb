# frozen_string_literal: true

require 'raindown/watcher/file_watcher'
require 'listen'
require 'tmpdir'

RSpec.describe Raindown::Watcher::FileWatcher do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  let(:path) { File.join(@dir, 'sample.md') }

  before { File.write(path, "# Title\n") }

  describe '#start' do
    subject(:watcher) { described_class.new(path:) }

    let(:on_change) { [] }

    before do
      allow(Listen).to receive(:to) do |_directory, &block|
        on_change << block
        instance_double(Listen::Listener, start: nil)
      end
      allow(watcher).to receive(:sleep)
    end

    it 'writes back to the file before watching, without writing HTML' do
      File.write(path, "# Title\n\n<{ toc: }>\n<{ :toc }>\n")

      expect { watcher.start }.to output(/Watching/).to_stdout
      expect(File.read(path)).to include('- [Title](#title)')
      expect(Dir.children(@dir)).to eq(['sample.md'])
    end

    it 'updates the Markdown TOC on save, and stops at the save that update makes' do
      File.write(path, "# Title\n\n<{ toc: }>\n<{ :toc }>\n")
      expect { watcher.start }.to output.to_stdout
      File.write(path, "#{File.read(path)}\n## Added\n")

      expect { on_change.first.call([path], [], []) }.to output(/Updated/).to_stdout
      expect(File.read(path)).to include('- [Added](#added)')

      expect { on_change.first.call([path], [], []) }.not_to output.to_stdout
    end

    it 'shows an error in the file and keeps watching' do
      File.write(path, "# Title\n\n<{ toc: }>\n")

      expect { watcher.start }.to output(/needs <\{ :toc \}>/).to_stderr.and output(/Watching/).to_stdout

      File.write(path, "# Fixed\n\n<{ toc: }>\n<{ :toc }>\n")
      expect { on_change.first.call([path], [], []) }.to output(/Updated/).to_stdout
      expect(File.read(path)).to include('- [Fixed](#fixed)')
    end

    it 'writes back bare directives when asked' do
      File.write(path, "# Title\n\ntoc:\n")
      bare_watcher = described_class.new(path:, bare: true)
      allow(bare_watcher).to receive(:sleep)

      expect { bare_watcher.start }.to output.to_stdout

      expect(File.read(path)).to include('- [Title](#title)')
    end

    it 'aligns Markdown tables on save' do
      expect { watcher.start }.to output.to_stdout
      File.write(path, "| a | b |\n|-|-|\n| ccc | d |\n")

      expect { on_change.first.call([path], [], []) }.to output(/Updated/).to_stdout
      expect(File.read(path)).to eq("| a   | b   |\n| --- | --- |\n| ccc | d   |\n")
    end

    it 'ignores changes to other files' do
      expect { watcher.start }.to output.to_stdout
      File.write(path, "| a | b |\n|-|-|\n| ccc | d |\n")

      expect { on_change.first.call([File.join(@dir, 'other.md')], [], []) }.not_to output.to_stdout
      expect(File.read(path)).to eq("| a | b |\n|-|-|\n| ccc | d |\n")
    end
  end
end
