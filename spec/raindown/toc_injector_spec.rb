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
  end
end
