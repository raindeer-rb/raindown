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
