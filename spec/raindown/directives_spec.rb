# frozen_string_literal: true

require 'raindown/directives'

RSpec.describe Raindown::Directives do
  describe '.marker' do
    it 'marks a directive or a whole directive line' do
      expect(described_class.marker("files: folder: 'notes'")).to eq("<!-- raindown:directive files: folder: 'notes' -->")
      expect(described_class.marker("<{ :files }>\n")).to eq('<!-- raindown:directive :files -->')
    end

    it 'keeps -- from ending the comment early' do
      expect(described_class.marker('A: title=a--b')).to eq('<!-- raindown:directive A: title=a- -b -->')
    end
  end

  describe '.render' do
    let(:html) { "#{described_class.marker('A: x=<b>')}\n<p>Text.</p>" }

    it 'shows each directive in bold, escaped' do
      expect(described_class.render(html)).to eq("<p><strong>A: x=&lt;b&gt;</strong></p>\n<p>Text.</p>")
    end

    it 'hides each directive in an HTML comment' do
      expect(described_class.render(html, hide: true)).to eq("<!-- A: x=<b> -->\n<p>Text.</p>")
    end
  end
end
