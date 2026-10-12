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

  describe '.file?' do
    it 'is true for Raindown extensions' do
      expect(%w[notes.rd notes.raindown NOTES.RD].map { |path| described_class.file?(path) }).to all(be(true))
    end

    it 'is false for Markdown and no path' do
      expect([described_class.file?('notes.md'), described_class.file?(nil)]).to all(be(false))
    end
  end
end
