# frozen_string_literal: true

require 'raindown'
require 'raindown/document'

RSpec.describe Raindown::Document do
  def headings(markdown) = described_class.parse(markdown).headings.map(&:to_h)

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
end
