# frozen_string_literal: true

require 'raindown/rewriter'
require 'tmpdir'

RSpec.describe Raindown::Rewriter do
  around do |example|
    Dir.mktmpdir do |dir|
      @path = File.join(dir, 'sample.md')
      example.run
    end
  end

  describe '.update' do
    it 'runs every rewriter over the file' do
      File.write(@path, "# Title\n\n<{ toc: }>\n<{ :toc }>\n\n| a | b |\n|-|-|\n| ccc | d |\n")

      expect(described_class.update(path: @path)).to be(true)

      content = File.read(@path)
      expect(content).to include("<{ toc: }>\n\n- [Title](#title)\n")
      expect(content).to include("| a   | b   |\n| --- | --- |\n| ccc | d   |\n")
    end

    it 'formats tables in files without a toc: block' do
      File.write(@path, "| a | b |\n|-|-|\n| ccc | d |\n")

      described_class.update(path: @path)

      expect(File.read(@path)).to eq("| a   | b   |\n| --- | --- |\n| ccc | d   |\n")
    end

    it 'does not write the file when nothing changes' do
      File.write(@path, "| a   | b   |\n| --- | --- |\n| ccc | d   |\n")
      allow(File).to receive(:write).and_call_original

      expect(described_class.update(path: @path)).to be(false)
      expect(File).not_to have_received(:write)
    end
  end
end
