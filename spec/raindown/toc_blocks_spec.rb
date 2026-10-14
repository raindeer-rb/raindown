# frozen_string_literal: true

require 'raindown/toc_blocks'

RSpec.describe Raindown::TOCBlocks do
  def find(markdown, bare: false)
    described_class.find(markdown.lines, bare:)
  end

  describe '.find' do
    it 'finds a block and the TOC below it' do
      expect(find("<{ toc: }>\n\n- [A](#a)\n  - [B](#b)\n\nText.\n")).to eq([{ open: 0, close: nil, last: 3 }])
    end

    it 'finds the end tag after the TOC' do
      expect(find("<{ toc: }>\n\n- [A](#a)\n\n<{ :toc }>\n")).to eq([{ open: 0, close: 4, last: 4 }])
      expect(find("<{ toc: }>\n<{ :toc }>\n")).to eq([{ open: 0, close: 1, last: 1 }])
    end

    it 'leaves a :toc after other text as its own directive' do
      expect(find("<{ toc: }>\n\nText.\n\n<{ :toc }>\n")).to eq([{ open: 0, close: nil, last: 0 }])
    end

    it 'leaves other lists alone' do
      expect(find("<{ toc: }>\n\n- [Docs](https://example.com)\n")).to eq([{ open: 0, close: nil, last: 0 }])
    end

    it 'skips code and front matter' do
      expect(find("---\ntoc:\n---\n\n```\n<{ toc: }>\n```\n", bare: true)).to eq([])
    end

    it 'reads bare directives when asked' do
      expect(find("toc:\n:toc\n", bare: true)).to eq([{ open: 0, close: 1, last: 1 }])
      expect(find("toc:\n:toc\n")).to eq([])
    end
  end

  describe '.to_directives' do
    it 'swaps each block for a :toc directive' do
      markdown = "# A\n\n<{ toc: }>\n\n- [A](#a)\n\n<{ :toc }>\n\nText.\n"

      expect(described_class.to_directives(markdown)).to eq("# A\n\n<{ :toc }>\n\nText.\n")
    end
  end
end
