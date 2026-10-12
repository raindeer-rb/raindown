# frozen_string_literal: true

require 'raindown/toc_injector'

RSpec.describe Raindown::TOCInjector do
  describe '.format' do
    let(:markdown) { "# Title\n\n<{ :toc }>\n\n## Section\n" }

    it 'injects a Markdown link list beneath the :toc directive' do
      expect(described_class.format(content: markdown)).to eq(<<~MARKDOWN)
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
      first_pass = described_class.format(content: markdown)

      expect(described_class.format(content: first_pass)).to eq(first_pass)
    end

    it 'updates an existing TOC block when headings change' do
      content = described_class.format(content: "#{described_class.format(content: markdown)}\n## New Section\n")

      expect(content.scan('raindown:toc').length).to eq(2)
      expect(content).to include('[New Section](#new-section)')
    end

    it 'leaves content without a :toc directive unchanged' do
      content = "# Title\n\n## Section\n"

      expect(described_class.format(content:)).to eq(content)
    end

    context 'with a Raindown file' do
      let(:markdown) { "# Title\n\n:toc\n\n## Section\n" }

      it 'injects the list beneath a bare :toc' do
        content = described_class.format(content: markdown, path: 'notes.rd')

        expect(content).to start_with("# Title\n\n:toc\n\n<!-- raindown:toc -->\n- [Title](#title)\n")
      end

      it 'is idempotent when nothing has changed' do
        first_pass = described_class.format(content: markdown, path: 'notes.rd')

        expect(described_class.format(content: first_pass, path: 'notes.rd')).to eq(first_pass)
      end

      it 'still accepts the delimited directive' do
        content = described_class.format(content: "# Title\n\n<{ :toc }>\n", path: 'notes.rd')

        expect(content).to include('<!-- raindown:toc -->')
      end

      it 'ignores :toc in prose' do
        content = "# Title\n\nUse :toc here.\n"

        expect(described_class.format(content:, path: 'notes.rd')).to eq(content)
      end
    end

    it 'ignores a bare :toc in Markdown files' do
      expect(described_class.format(content: markdown.sub('<{ :toc }>', ':toc'), path: 'notes.md'))
        .not_to include('raindown:toc')
    end
  end
end
