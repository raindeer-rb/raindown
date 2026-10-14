# frozen_string_literal: true

require 'raindown/toc_blocks'

RSpec.describe Raindown::TOCBlocks do
  def find(markdown, bare: false)
    described_class.find(markdown.lines, bare:)
  end

  describe '.find' do
    it 'finds a block, its TOC and its end tag' do
      expect(find("<{ toc: }>\n\n- [A](#a)\n  - [B](#b)\n\n<{ :toc }>\n")).to eq([{ open: 0, close: 5, last: 5 }])
      expect(find("<{ toc: }>\n<{ :toc }>\n")).to eq([{ open: 0, close: 1, last: 1 }])
    end

    it 'raises when a block has no end tag after its TOC' do
      ["<{ toc: }>\n\n- [A](#a)\n\nText.\n\n<{ :toc }>\n", "<{ toc: }>\n- [A](#a)\n"].each do |markdown|
        expect { find(markdown) }.to raise_error(described_class::MissingEndTag, /line 1 needs <\{ :toc \}>/)
      end
    end

    it 'ends a bare block with its TOC' do
      expect(find("toc:\n\n- [A](#a)\n  - [B](#b)\n\nText.\n", bare: true)).to eq([{ open: 0, close: nil, last: 3 }])
    end

    it 'leaves a bare :toc after the TOC as its own directive' do
      expect(find("toc:\n\n- [A](#a)\n:toc\n", bare: true)).to eq([{ open: 0, close: nil, last: 2 }])
    end

    it 'leaves other lists alone' do
      expect(find("toc:\n\n- [Docs](https://example.com)\n", bare: true)).to eq([{ open: 0, close: nil, last: 0 }])
    end

    it 'skips code and front matter' do
      expect(find("---\ntoc:\n---\n\n```\n<{ toc: }>\n```\n", bare: true)).to eq([])
    end

    it 'only reads bare blocks when asked' do
      expect(find("toc:\n")).to eq([])
    end
  end

  describe '.to_directives' do
    it 'swaps each block for a :toc directive' do
      markdown = "# A\n\n<{ toc: }>\n\n- [A](#a)\n\n<{ :toc }>\n\ntoc:\n\n- [A](#a)\n\nText.\n"

      expect(described_class.to_directives(markdown, bare: true)).to eq("# A\n\n<{ :toc }>\n\n<{ :toc }>\n\nText.\n")
    end
  end
end
