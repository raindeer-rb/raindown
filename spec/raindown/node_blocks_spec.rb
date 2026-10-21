# frozen_string_literal: true

require 'raindown'
require 'helpers/nodes'

RSpec.describe Raindown::NodeBlocks do
  def find(markdown, bare: false)
    described_class.find(markdown.lines, front_matter: Raindown::FrontMatter.parse(markdown).first, bare:)
                   .map { |block| block.except(:node).merge(node: block[:node].class) }
  end

  describe '.find' do
    it 'finds a delimited block up to its end tag' do
      expect(find("<{ SpecReleases: limit=2 }>\n\n- old\n\n<{ :SpecReleases }>\n"))
        .to eq([{ open: 0, close: 4, last: 4, node: SpecReleases }])
    end

    it 'raises when a delimited block has no end tag' do
      expect { find("<{ SpecReleases: }>\n\nText.\n") }
        .to raise_error(described_class::MissingEndTag, /line 1 needs <\{ :SpecReleases \}>/)
    end

    it 'ends a bare block at the next blank line, with fenced code kept whole' do
      expect(find("SpecReleases: limit=2\n- a\n```\nb\n\nc\n```\n\nText.\n", bare: true))
        .to eq([{ open: 0, close: nil, last: 6, node: SpecReleases }])
      expect(find("SpecReleases:\n\nText.\n", bare: true)).to eq([{ open: 0, close: nil, last: 0, node: SpecReleases }])
    end

    it 'only reads bare blocks when asked' do
      expect(find("SpecReleases:\n")).to eq([])
    end

    it 'leaves names that are not nodes alone' do
      expect(find("Note: this is prose.\n\n<{ Unknown: }>\n", bare: true)).to eq([])
    end

    it 'skips code and front matter' do
      expect(find("---\nSpecReleases: 1\n---\n\n```\n<{ SpecReleases: }>\n```\n", bare: true)).to eq([])
    end

    it 'shares one instance between blocks with the same node and props' do
      lines = "SpecReleases: limit=2\n\nSpecReleases: limit=2\n\nSpecReleases: limit=1\n".lines
      nodes = described_class.find(lines, bare: true).map { |block| block[:node] }

      expect(nodes[0]).to be(nodes[1])
      expect(nodes[0]).not_to be(nodes[2])
    end
  end

  describe '.props' do
    it 'reads quoted text, numbers, booleans and variables' do
      variables = Raindown::Variables.new(author: { name: 'Mark' })
      props = described_class.props(%(a='x y' b="z" c=3 d=1.5 e=true f=author.name g=missing), variables)

      expect(props).to eq(a: 'x y', b: 'z', c: 3, d: 1.5, e: true, f: 'Mark', g: nil)
    end

    it 'reads nil, false, negative numbers and symbols as values' do
      props = described_class.props('a=nil b=false c=-2 d=:draft', Raindown::Variables.new(nil: 'x'))

      expect(props).to eq(a: nil, b: false, c: -2, d: :draft)
    end

    it 'reads variables as the data they are, with their braces' do
      variables = Raindown::Variables.new(rows: [{ name: '{a}', count: 1 }], tags: %w[x y])

      expect(described_class.props('a=rows b=tags.first', variables)).to eq(a: [{ name: '{a}', count: 1 }], b: 'x')
    end
  end

  describe '.args' do
    let(:none) { Raindown::Variables.new({}) }

    it 'reads a value before the props as the argument' do
      expect(described_class.args("'data.csv' format: 'columns'", none)).to eq([{ format: 'columns' }, ['data.csv']])
      expect(described_class.args('stats', Raindown::Variables.new(stats: { a: 1 }))).to eq([{}, [{ a: 1 }]])
    end

    it 'has no argument when the props come first' do
      expect(described_class.args('limit=2 b: 3', none)).to eq([{ limit: 2, b: 3 }])
      expect(described_class.args('', none)).to eq([{}])
    end
  end

  describe '.to_rendered' do
    it 'swaps a node with HTML for a placeholder, and one without for its Markdown, with directive markers' do
      markdown = "<{ SpecReleases: limit=1 }>\n- old\n<{ :SpecReleases }>\n\nSpecHeading: title='Hi'\n"
      rendered = described_class.to_rendered(markdown, bare: true)

      expect(rendered).to match(/\A<!-- raindown:directive SpecReleases: limit=1 -->\n<!-- raindown:node \d+ -->\n/)
        .and include("<!-- raindown:directive :SpecReleases -->\n\n")
        .and end_with("<!-- raindown:directive SpecHeading: title='Hi' -->\n## Hi\n")
    end
  end
end
