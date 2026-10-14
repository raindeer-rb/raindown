# frozen_string_literal: true

require 'raindown/toc_injector'

RSpec.describe Raindown::TOCInjector do
  describe '.rewrite' do
    let(:markdown) { "# Title\n\n<{ toc: }>\n\n## Section\n" }

    it 'injects a Markdown link list beneath a toc: block' do
      expect(described_class.rewrite(content: markdown)).to eq(<<~MARKDOWN)
        # Title

        <{ toc: }>

        - [Title](#title)
          - [Section](#section)

        ## Section
      MARKDOWN
    end

    it 'keeps an end tag after the list' do
      content = "# Title\n\n<{ toc: }>\n<{ :toc }>\n\nText.\n"

      expect(described_class.rewrite(content:)).to eq("# Title\n\n<{ toc: }>\n\n- [Title](#title)\n\n<{ :toc }>\n\nText.\n")
    end

    it 'is idempotent when nothing has changed' do
      first_pass = described_class.rewrite(content: markdown)

      expect(described_class.rewrite(content: first_pass)).to eq(first_pass)
    end

    it 'updates an existing TOC when headings change' do
      content = described_class.rewrite(content: "#{described_class.rewrite(content: markdown)}\n## New Section\n")

      expect(content.scan('- [Title](#title)').length).to eq(1)
      expect(content).to include("  - [Section](#section)\n  - [New Section](#new-section)\n")
    end

    it 'fills every toc: block' do
      content = described_class.rewrite(content: "# Title\n\n<{ toc: }>\n\nText.\n\n<{ toc: }>\n")

      expect(content.scan('- [Title](#title)').length).to eq(2)
    end

    it 'lists headings with their variables rendered' do
      content = "---\nname: Mark\n---\n\n# Notes for {name}\n\n<{ toc: }>\n"

      expect(described_class.rewrite(content:)).to include('- [Notes for Mark](#notes-for-mark)')
    end

    it 'leaves a :toc directive alone' do
      content = "# Title\n\n<{ :toc }>\n\n## Section\n"

      expect(described_class.rewrite(content:)).to eq(content)
    end

    it 'skips toc: directives in code' do
      content = "# Café\n\n```\n<{ toc: }>\n```\n"

      expect(described_class.rewrite(content:)).to eq(content)
      expect(described_class.rewrite(content: "#{content}\n<{ toc: }>\n")).to end_with("```\n\n<{ toc: }>\n\n- [Café](#café)\n")
    end

    context 'with a Raindown file' do
      let(:markdown) { "# Title\n\ntoc:\n\n## Section\n" }

      it 'injects the list beneath a bare toc:' do
        content = described_class.rewrite(content: markdown, path: 'notes.rd')

        expect(content).to start_with("# Title\n\ntoc:\n\n- [Title](#title)\n")
      end

      it 'keeps a bare end tag' do
        content = described_class.rewrite(content: "# Title\n\ntoc:\n:toc\n", path: 'notes.rd')

        expect(content).to eq("# Title\n\ntoc:\n\n- [Title](#title)\n\n:toc\n")
      end

      it 'ignores toc: in front matter' do
        content = "---\ntoc:\n  - a\n---\n\n# Title\n"

        expect(described_class.rewrite(content:, path: 'notes.rd')).to eq(content)
      end
    end

    it 'ignores a bare toc: in Markdown files unless asked' do
      content = "# Title\n\ntoc:\n"

      expect(described_class.rewrite(content:, path: 'notes.md')).to eq(content)
      expect(described_class.rewrite(content:, path: 'notes.md', bare: true)).to include('- [Title](#title)')
    end
  end
end
