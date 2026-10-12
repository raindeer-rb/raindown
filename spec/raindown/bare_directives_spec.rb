# frozen_string_literal: true

require 'raindown/bare_directives'

RSpec.describe Raindown::BareDirectives do
  describe '.expand' do
    it 'wraps a directive on its own line' do
      expect(described_class.expand("# Title\n\n:toc\n\nText.\n")).to eq("# Title\n\n<{ :toc }>\n\nText.\n")
    end

    it 'wraps every keyword directive' do
      expect(described_class.expand(":list\n")).to eq("<{ :list }>\n")
    end

    it 'keeps up to three spaces of indent' do
      expect(described_class.expand("   :toc  \n")).to eq("   <{ :toc }>\n")
    end

    it 'expands a directive on the last line without a newline' do
      expect(described_class.expand("Text.\n\n:toc")).to eq("Text.\n\n<{ :toc }>")
    end

    {
      'inline in prose' => "Use :toc here.\n",
      'indented as code' => "    :toc\n",
      'in a backtick fence' => "```\n:toc\n```\n",
      'in a tilde fence' => "~~~\n:toc\n~~~\n",
      'an unknown keyword' => ":foo\n",
      'an emoji shortcode' => ":toc:\n",
      'already wrapped' => "<{ :toc }>\n"
    }.each do |description, content|
      it "leaves a directive #{description} alone" do
        expect(described_class.expand(content)).to eq(content)
      end
    end
  end

  describe '.enabled?' do
    it 'is enabled by the flag, a Raindown file or front matter' do
      expect(described_class.enabled?(content: '', path: 'notes.md', bare: true)).to be(true)
      expect(described_class.enabled?(content: '', path: 'notes.rd')).to be(true)
      expect(described_class.enabled?(content: "---\nbare: true\n---\n", path: 'notes.md')).to be(true)
    end

    it 'is disabled for plain Markdown' do
      expect(described_class.enabled?(content: "# Title\n", path: 'notes.md')).to be(false)
    end
  end

  describe '.front_matter?' do
    it 'is true when the front matter sets bare: true' do
      expect(described_class.front_matter?("---\ntitle: Notes\ndate: 2026-10-13\nbare: true\n---\n\n# Notes\n")).to be(true)
    end

    {
      'bare: false' => "---\nbare: false\n---\n",
      'no bare key' => "---\ntitle: Notes\n---\n",
      'a nested bare key' => "---\nraindown:\n  bare: true\n---\n",
      'bare: true outside front matter' => "# Notes\n\nbare: true\n",
      'front matter that is not at the start' => "# Notes\n\n---\nbare: true\n---\n",
      'unclosed front matter' => "---\nbare: true\n"
    }.each do |description, content|
      it "is false for #{description}" do
        expect(described_class.front_matter?(content)).to be(false)
      end
    end
  end

  describe '.file?' do
    it 'is true for Raindown extensions' do
      expect(%w[notes.rd notes.raindown NOTES.RD].map { |path| described_class.file?(path) }).to all(be(true))
    end

    it 'is false for Markdown and no path' do
      expect([described_class.file?('notes.md'), described_class.file?(nil)]).to all(be(false))
    end
  end
end
