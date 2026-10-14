# frozen_string_literal: true

require 'raindown/node_injector'
require 'helpers/nodes'

RSpec.describe Raindown::NodeInjector do
  def rewrite(content, path: 'notes.md')
    described_class.rewrite(content:, path:)
  end

  it 'writes a node between its tags' do
    expect(rewrite("<{ SpecReleases: limit=2 }>\n<{ :SpecReleases }>\n\nText.\n"))
      .to eq("<{ SpecReleases: limit=2 }>\n\n- **1.2.0** Bare\n- **1.1.0** Fetched\n\n<{ :SpecReleases }>\n\nText.\n")
  end

  it 'writes a bare node straight below it' do
    expect(rewrite("SpecReleases: limit=1\n\nText.\n", path: 'notes.rd')).to eq("SpecReleases: limit=1\n- **1.2.0** Bare\n\nText.\n")
  end

  it 'replaces what it wrote before' do
    content = "SpecReleases: limit=1\n- old\n- older\n\nText.\n"

    expect(rewrite(content, path: 'notes.rd')).to eq("SpecReleases: limit=1\n- **1.2.0** Bare\n\nText.\n")
  end

  it 'is idempotent' do
    once = rewrite("<{ SpecParagraphs: }>\n<{ :SpecParagraphs }>\n\nSpecReleases:\n", path: 'notes.rd')

    expect(rewrite(once, path: 'notes.rd')).to eq(once)
  end

  it 'raises when a bare node writes blank lines' do
    expect { rewrite("SpecParagraphs:\n", path: 'notes.rd') }
      .to raise_error(described_class::BlankLine, /needs <\{ SpecParagraphs: \}> and <\{ :SpecParagraphs \}>/)
  end

  it 'leaves content without node blocks unchanged' do
    content = "Note: this is prose.\n"

    expect(rewrite(content, path: 'notes.rd')).to eq(content)
  end
end
