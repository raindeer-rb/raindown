# frozen_string_literal: true

require 'raindown'
require 'cgi'

RSpec.describe Raindown do
  describe '.render' do
    def text(html)
      CGI.unescapeHTML(Nokogiri::HTML(html).text)
    end

    it 'keeps directives in code blocks as-is' do
      html = described_class.render(markdown: "```\n<{ :toc }>\n```\n")

      expect(text(html)).to include('<{ :toc }>')
      expect(html).not_to include('Table of contents')
    end

    it 'keeps braces in code blocks' do
      html = described_class.render(markdown: "```ruby\nh = { a: 1 }\n```\n")

      expect(text(html)).to include('h = { a: 1 }')
    end

    it 'keeps braces in inline code' do
      html = described_class.render(markdown: "Use `<{` and `}>` around `x = { b: 2 }`.\n")

      expect(text(html)).to include('Use <{ and }> around x = { b: 2 }.')
    end

    it 'ends with a single newline' do
      plain = described_class.render(markdown: "# Title\n")
      directive = described_class.render(markdown: "# Title\n\n<{ :toc }>\n\nText.\n")

      expect([plain, directive]).to all(end_with("\n").and(satisfy { |html| !html.end_with?("\n\n") }))
    end

    it 'still renders directives outside code' do
      html = described_class.render(markdown: "# Title\n\n<{ :toc }>\n\n```\n<{ :toc }>\n```\n")

      expect(html.scan('Table of contents').length).to eq(1)
    end
  end
end
