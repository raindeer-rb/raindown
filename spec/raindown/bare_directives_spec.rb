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

    it 'closes block directives after the code blocks they hold' do
      content = "endpoint: :x\n\n```sh\ncurl x\n```\n\n```json\n{}\n```\n\nAfter\n"

      expect(described_class.expand(content))
        .to eq("<{ endpoint: :x }>\n\n```sh\ncurl x\n```\n\n```json\n{}\n```\n<{ :endpoint }>\n\nAfter\n")
    end

    it 'only closes around code blocks directly below' do
      content = "endpoint:\n```sh\ncurl x\n```\nText\n```\nother\n```\n"

      expect(described_class.expand(content)).to eq("<{ endpoint: }>\n```sh\ncurl x\n```\n<{ :endpoint }>\nText\n```\nother\n```\n")
    end

    it 'closes an endpoint before another curl example' do
      content = "endpoint: :x\n\n```sh\ncurl x\n```\n\n```sh\ncurl y\n```\n"

      expect(described_class.expand(content)).to eq("<{ endpoint: :x }>\n\n```sh\ncurl x\n```\n<{ :endpoint }>\n\n```sh\ncurl y\n```\n")
    end

    it 'closes block directives with nothing below them straight away' do
      expect(described_class.expand("endpoint:\n\nText")).to eq("<{ endpoint: }>\n<{ :endpoint }>\n\nText")
    end

    it 'closes block directives at the end of the file' do
      expect(described_class.expand("endpoint:\n```sh\ncurl x\n```")).to eq("<{ endpoint: }>\n```sh\ncurl x\n```\n<{ :endpoint }>\n")
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
      'a keyword without a space before its arguments' => "endpoint:x\n",
      'a capitalised keyword' => "Endpoint: :x\n",
      'an emoji shortcode' => ":toc:\n",
      'already wrapped' => "<{ :toc }>\n"
    }.each do |description, content|
      it "leaves a directive #{description} alone" do
        expect(described_class.expand(content)).to eq(content)
      end
    end
  end

  describe '.enabled?' do
    it 'is enabled by the flag or a Raindown file' do
      expect(described_class.enabled?(path: 'notes.md', bare: true)).to be(true)
      expect(described_class.enabled?(path: 'notes.rd')).to be(true)
    end

    it 'is disabled for Markdown files' do
      expect(described_class.enabled?(path: 'notes.md')).to be(false)
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
