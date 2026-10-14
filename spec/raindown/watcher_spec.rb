# frozen_string_literal: true

require 'raindown/watcher'
require 'listen'
require 'tmpdir'

RSpec.describe Raindown::Watcher do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  let(:path) { File.join(@dir, 'sample.md') }
  let(:output_path) { File.join(@dir, 'sample.html') }

  before { File.write(path, "# Title\n") }

  describe '#output' do
    it 'defaults to an HTML file beside the Markdown file' do
      expect(described_class.new(path:).output).to eq(output_path)
    end
  end

  describe '#start' do
    subject(:watcher) { described_class.new(path:, output: output_path) }

    let(:on_change) { [] }

    before do
      allow(Listen).to receive(:to) do |_directory, &block|
        on_change << block
        instance_double(Listen::Listener, start: nil)
      end
      allow(watcher).to receive(:sleep)
    end

    it 'renders the file before watching' do
      expect { watcher.start }.to output(/Watching/).to_stdout

      expect(File.read(output_path)).to include('Title')
    end

    it 'updates the Markdown TOC then renders on the change that update triggers' do
      File.write(path, "# Title\n\n<{ toc: }>\n<{ :toc }>\n")
      expect { watcher.start }.to output.to_stdout
      File.write(path, "#{File.read(path)}\n## Added\n")

      expect { on_change.first.call([path], [], []) }.not_to output.to_stdout
      expect(File.read(path)).to include('- [Added](#added)')

      expect { on_change.first.call([path], [], []) }.to output(/Re-rendered/).to_stdout
      expect(File.read(output_path)).to include('Added')
    end

    it 'renders bare directives when asked' do
      File.write(path, "# Title\n\ntoc:\n")
      bare_watcher = described_class.new(path:, output: output_path, bare: true)
      allow(bare_watcher).to receive(:sleep)

      expect { bare_watcher.start }.to output.to_stdout

      expect(File.read(path)).to include('- [Title](#title)')
      expect(File.read(output_path)).to include('Table of contents')
    end

    it 'aligns Markdown tables on save' do
      expect { watcher.start }.to output.to_stdout
      File.write(path, "| a | b |\n|-|-|\n| ccc | d |\n")

      expect { on_change.first.call([path], [], []) }.not_to output.to_stdout
      expect(File.read(path)).to eq("| a   | b   |\n| --- | --- |\n| ccc | d   |\n")

      expect { on_change.first.call([path], [], []) }.to output(/Re-rendered/).to_stdout
      expect(File.read(output_path)).to include('<table>')
    end

    it 're-renders when the file changes' do
      expect { watcher.start }.to output.to_stdout
      File.write(path, "# Changed\n")

      expect { on_change.first.call([path], [], []) }.to output(/Re-rendered/).to_stdout
      expect(File.read(output_path)).to include('Changed')
    end

    it 'ignores changes to other files' do
      expect { watcher.start }.to output.to_stdout
      File.write(path, "# Changed\n")

      expect { on_change.first.call([File.join(@dir, 'other.md')], [], []) }.not_to output.to_stdout
      expect(File.read(output_path)).not_to include('Changed')
    end
  end
end
