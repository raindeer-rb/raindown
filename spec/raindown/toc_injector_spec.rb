# frozen_string_literal: true

require 'raindown/toc_injector'

RSpec.describe Raindown::TOCInjector do
  describe '.format' do
    let(:markdown) { "# Title\n\n<{ :toc }>\n\n## Section\n" }

    it 'injects a Markdown link list beneath the :toc directive' do
      expect(described_class.rewrite(content: markdown)).to eq(<<~MARKDOWN)
        # Title

        <{ :toc }>

        <!-- raindown:toc -->
        - [Title](#title)
          - [Section](#section)
        <!-- /raindown:toc -->

        ## Section
      MARKDOWN
    end

    it 'is idempotent when nothing has changed' do
      first_pass = described_class.rewrite(content: markdown)

      expect(described_class.rewrite(content: first_pass)).to eq(first_pass)
    end

    it 'updates an existing TOC block when headings change' do
      content = described_class.rewrite(content: "#{described_class.rewrite(content: markdown)}\n## New Section\n")

      expect(content.scan('raindown:toc').length).to eq(2)
      expect(content).to include('[New Section](#new-section)')
    end

    it 'lists headings with their variables rendered' do
      content = "---\nname: Mark\n---\n\n# Notes for {name}\n\n<{ :toc }>\n"

      expect(described_class.rewrite(content:)).to include('- [Notes for Mark](#notes-for-mark)')
    end

    it 'leaves content without a :toc directive unchanged' do
      content = "# Title\n\n## Section\n"

      expect(described_class.rewrite(content:)).to eq(content)
    end

    it 'skips :toc directives in code' do
      content = "# Café\n\nUse `<{ :toc }>` like this:\n\n```\n<{ :toc }>\n```\n"

      expect(described_class.rewrite(content:)).to eq(content)
      expect(described_class.rewrite(content: "#{content}\n<{ :toc }>\n"))
        .to end_with("```\n\n<{ :toc }>\n\n<!-- raindown:toc -->\n- [Café](#café)\n<!-- /raindown:toc -->\n")
    end

    context 'with a Raindown file' do
      let(:markdown) { "# Title\n\n:toc\n\n## Section\n" }

      it 'injects the list beneath a bare :toc' do
        content = described_class.rewrite(content: markdown, path: 'notes.rd')

        expect(content).to start_with("# Title\n\n:toc\n\n<!-- raindown:toc -->\n- [Title](#title)\n")
      end

      it 'is idempotent when nothing has changed' do
        first_pass = described_class.rewrite(content: markdown, path: 'notes.rd')

        expect(described_class.rewrite(content: first_pass, path: 'notes.rd')).to eq(first_pass)
      end

      it 'still accepts the delimited directive' do
        content = described_class.rewrite(content: "# Title\n\n<{ :toc }>\n", path: 'notes.rd')

        expect(content).to include('<!-- raindown:toc -->')
      end

      it 'ignores :toc in prose' do
        content = "# Title\n\nUse :toc here.\n"

        expect(described_class.rewrite(content:, path: 'notes.rd')).to eq(content)
      end
    end

    it 'injects beneath a bare :toc in Markdown files when asked' do
      content = markdown.sub('<{ :toc }>', ':toc')

      expect(described_class.rewrite(content:, path: 'notes.md', bare: true)).to include("\n:toc\n\n<!-- raindown:toc -->\n")
    end

    it 'ignores a bare :toc in Markdown files' do
      expect(described_class.rewrite(content: markdown.sub('<{ :toc }>', ':toc'), path: 'notes.md'))
        .not_to include('raindown:toc')
    end
  end
end
