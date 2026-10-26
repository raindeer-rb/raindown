# frozen_string_literal: true

require 'raindown'
require 'raindown/document'
require 'helpers/nodes'
require 'tmpdir'

RSpec.describe Raindown::Document do
  def headings(markdown) = described_class.parse(markdown).headings.map(&:to_h)
  def directives(markdown, bare: false) = described_class.parse(markdown, bare:).directives.map(&:to_h)

  describe '#headings' do
    it 'reads the level, text and line of each heading' do
      expected = [
        { level: 1, text: 'Notes', line: 1 }, { level: 2, text: 'Setup', line: 5 }, { level: 3, text: 'Deeper', line: 7 }
      ]

      expect(headings("# Notes\n\nText.\n\n## Setup\n\n### Deeper\n")).to eq(expected)
    end

    it 'counts lines from the top of the file, including front matter' do
      expect(headings("---\ntitle: Notes\n---\n\n# {title}\n")).to eq([{ level: 1, text: '{title}', line: 5 }])
    end

    it 'reads the text a reader sees, leaving out inline HTML tags' do
      expect(headings("# Hello `code` *em* <b>tag</b>\n")).to eq([{ level: 1, text: 'Hello code em tag', line: 1 }])
    end

    it 'reads headings underlined with = or -' do
      expected = [{ level: 1, text: 'Title', line: 1 }, { level: 2, text: 'Section', line: 4 }]

      expect(headings("Title\n=====\n\nSection\n-------\n")).to eq(expected)
    end

    it 'leaves out lines in code blocks that look like headings' do
      expect(headings("# Real\n\n```md\n# Not a heading\n```\n")).to eq([{ level: 1, text: 'Real', line: 1 }])
    end

    it 'reads headings that a directive wrote back into the file' do
      markdown = "# Notes\n\n<{ Changelog: }>\n\n## 1.0.0\n\n- Released\n\n<{ :Changelog }>\n"

      expect(headings(markdown).map { it[:text] }).to eq(['Notes', '1.0.0'])
    end

    it 'is empty without headings' do
      expect(headings("Just text.\n")).to be_empty
    end
  end

  describe '#directives' do
    it 'reads a delimited node, with the lines it wrote and not the blank lines around them' do
      markdown = "# Notes\n\n<{ SpecReleases: limit=2 }>\n\n- **1.2.0** Bare\n- **1.1.0** Fetched\n\n<{ :SpecReleases }>\n"

      expect(directives(markdown))
        .to eq([{ name: 'SpecReleases', args: 'limit=2', line: 3, end_line: 8, output: 5..6, writes: true }])
    end

    it 'has no output before a node writes any' do
      expect(directives("<{ toc: }>\n<{ :toc }>\n"))
        .to eq([{ name: 'toc', args: '', line: 1, end_line: 2, output: nil, writes: true }])
    end

    it 'reads self-closing nodes, which never write' do
      expect(directives("# Notes\n\n<{ :toc }>\n"))
        .to eq([{ name: 'toc', args: '', line: 3, end_line: 3, output: nil, writes: false }])
    end

    it 'reads bare nodes in Raindown files, up to the next blank line' do
      markdown = "toc:\n- [Notes](#notes)\n\n# Notes\n\n:toc\n"

      expect(directives(markdown, bare: true)).to eq(
        [{ name: 'toc', args: '', line: 1, end_line: 2, output: 2..2, writes: true },
         { name: 'toc', args: '', line: 6, end_line: 6, output: nil, writes: false }]
      )
      expect(directives(markdown)).to be_empty
    end

    it "reads an endpoint, whose output is its response and the date it was fetched, not the author's snippet" do
      markdown = <<~MARKDOWN
        <{ endpoint: :x }>

        ```sh
        curl https://example.com
        ```

        ```json
        { "id": 1 }
        ```
        <!-- raindown:fetched 2026-10-14 -->
        <{ :endpoint }>
      MARKDOWN

      expect(directives(markdown)).to eq([{ name: 'endpoint', args: ':x', line: 1, end_line: 11, output: 7..10, writes: true }])
    end

    it 'reads an endpoint without a response yet, and a bare endpoint, which ends after its blocks' do
      waiting = "<{ endpoint: }>\n```sh\ncurl https://example.com\n```\n<{ :endpoint }>\n"
      bare = "endpoint: :x\n```sh\ncurl https://example.com\n```\n```json\n{}\n```\n\nText.\n"

      expect(directives(waiting)).to eq([{ name: 'endpoint', args: '', line: 1, end_line: 5, output: nil, writes: true }])
      expect(directives(bare, bare: true))
        .to eq([{ name: 'endpoint', args: ':x', line: 1, end_line: 7, output: 5..7, writes: true }])
    end

    it 'leaves out directives in code and front matter, template directives and names that are not nodes' do
      markdown = "---\ntoc: true\n---\n\n```md\n<{ :toc }>\n```\n\n<{ if: draft }>\nDraft.\n<{ :if }>\n\nNote: prose.\n"

      expect(directives(markdown, bare: true)).to be_empty
    end

    it 'lists the directives in the order they appear' do
      markdown = "<{ endpoint: }>\n```sh\ncurl https://example.com\n```\n<{ :endpoint }>\n\n<{ :toc }>\n"

      expect(directives(markdown).map { it[:name] }).to eq(%w[endpoint toc])
    end
  end

  describe '#outline' do
    it 'has the headings and directives in the order they appear' do
      outline = described_class.parse("# Notes\n\n<{ :toc }>\n\n## Setup\n").outline

      expect(outline.map(&:class)).to eq([described_class::Heading, described_class::Directive, described_class::Heading])
    end
  end

  describe '.read' do
    it 'reads bare directives in Raindown files' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'notes.rd'), ":toc\n")
        File.write(File.join(dir, 'notes.md'), ":toc\n")

        expect(described_class.read(File.join(dir, 'notes.rd')).directives.length).to eq(1)
        expect(described_class.read(File.join(dir, 'notes.md')).directives).to be_empty
      end
    end
  end
end
