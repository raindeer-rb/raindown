# frozen_string_literal: true

require 'raindown/front_matter'

RSpec.describe Raindown::FrontMatter do
  describe '.parse' do
    it 'splits the metadata from the Markdown' do
      metadata, markdown = described_class.parse("---\ntitle: Notes\nbare: true\n---\n\n# Notes\n")

      expect(metadata).to eq(title: 'Notes', bare: true)
      expect(markdown).to eq("\n# Notes\n")
    end

    it 'loads dates and times' do
      metadata, = described_class.parse("---\ndate: 2026-10-13\nupdated: 2026-10-13 09:00:00 Z\n---\n")

      expect(metadata[:date]).to eq(Date.new(2026, 10, 13))
      expect(metadata[:updated]).to be_a(Time)
    end

    it 'returns no metadata without front matter' do
      expect(described_class.parse("# Notes\n")).to eq([{}, "# Notes\n"])
    end

    it 'ignores horizontal rules after the start of the file' do
      content = "# Notes\n\n---\ntitle: Not metadata\n---\n"

      expect(described_class.parse(content)).to eq([{}, content])
    end

    it 'returns no metadata for empty front matter' do
      expect(described_class.parse("---\n---\n# Notes\n")).to eq([{}, "# Notes\n"])
    end

    it 'raises on invalid YAML' do
      expect { described_class.parse("---\ntitle: [\n---\n") }.to raise_error(Psych::SyntaxError)
    end
  end
end
