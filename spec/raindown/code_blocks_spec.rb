# frozen_string_literal: true

require 'raindown/code_blocks'

RSpec.describe Raindown::CodeBlocks do
  describe '.at' do
    it 'reads the block opening at the index' do
      lines = "Text\n```json title=x\n{}\n```\n".lines

      expect(described_class.at(lines, 1)).to eq(open: 1, close: 3, language: 'json', body: "{}\n")
    end

    it 'needs a closing fence as long as the opening one' do
      lines = "````\n```\n````\n".lines

      expect(described_class.at(lines, 0)).to include(close: 2, body: "```\n")
    end

    it 'is nil for unclosed blocks and other lines' do
      expect(described_class.at("```\ncode\n".lines, 0)).to be_nil
      expect(described_class.at("Text\n".lines, 0)).to be_nil
    end
  end

  describe '.endpoint' do
    let(:snippet) { "```sh\ncurl https://api.example.com\n```\n" }

    def blocks(content)
      described_class.endpoint(content.lines, 0).map { |block| block[:body] }
    end

    it 'holds the snippet and its response' do
      expect(blocks("#{snippet}\n```json\n{}\n```\n")).to eq(["curl https://api.example.com\n", "{}\n"])
    end

    it 'holds only the snippet before there is a response' do
      expect(blocks("#{snippet}\nText\n```json\n{}\n```\n")).to eq(["curl https://api.example.com\n"])
    end

    {
      'sh' => "```sh\nls\n```\n",
      'bash' => "```bash\nls\n```\n",
      'curl' => "```curl\nhttps://api.example.com\n```\n",
      'capitalised Bash' => "```Bash\nls\n```\n",
      'a curl command without a language' => "```\ncurl https://api.example.com/other\n```\n"
    }.each do |description, other|
      it "treats a following #{description} block as another example" do
        expect(blocks("#{snippet}\n#{other}").length).to eq(1)
      end
    end
  end
end
