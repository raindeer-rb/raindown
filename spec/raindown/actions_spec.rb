# frozen_string_literal: true

require 'raindown/actions'
require 'raindown/document'
require 'tmpdir'

RSpec.describe Raindown::Actions do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  let(:curl) { "```sh\ncurl https://api.example.com/users\n```\n" }

  def write(name, content)
    File.join(@dir, name).tap { File.write(it, content) }
  end

  describe '.write_back' do
    it 'writes back the whole file, and is false when nothing changed' do
      path = write('notes.md', "# Notes\n\n<{ toc: }>\n<{ :toc }>\n")

      expect(described_class.write_back(path)).to be(true)
      expect(File.read(path)).to include('- [Notes](#notes)')
      expect(described_class.write_back(path)).to be(false)
    end
  end

  describe '.execute' do
    before do
      allow(Raindown::Curl).to receive(:run).and_return(['{ "id": 2 }', 'json'])
      allow(Date).to receive(:today).and_return(Date.new(2026, 10, 20))
    end

    it "runs the endpoint and replaces its response, leaving the file's other endpoints alone" do
      path = write('api.md', "<{ endpoint: }>\n\n#{curl}\n```json\n{}\n```\n\n<{ endpoint: }>\n\n#{curl}\n```json\n{}\n```\n")
      second = Raindown::Document.read(path).directives.last

      expect(described_class.execute(path, second)).to be(true)
      expect(File.read(path).scan('{ "id": 2 }').length).to eq(1)
      expect(File.read(path)).to end_with("```json\n{ \"id\": 2 }\n```\n<!-- raindown:fetched 2026-10-20 -->\n")
    end

    it 'runs bare endpoints in Raindown files' do
      path = write('api.rd', "endpoint:\n#{curl}")

      expect(described_class.execute(path, Raindown::Document.read(path).directives.first)).to be(true)
      expect(File.read(path)).to include('{ "id": 2 }')
    end

    it "raises for a directive that isn't an endpoint" do
      path = write('notes.md', "<{ :toc }>\n")

      expect { described_class.execute(path, Raindown::Document.read(path).directives.first) }
        .to raise_error(described_class::NotAnEndpoint, "toc on line 1 isn't an endpoint")
    end
  end

  describe '.edit_command' do
    it 'opens the file at the line in the editor' do
      expect(described_class.edit_command('a.md', line: 12, editor: 'vim')).to eq(['vim', '+12', 'a.md'])
      expect(described_class.edit_command('a.md', line: 12, editor: 'emacs -nw')).to eq(['emacs', '-nw', '+12', 'a.md'])
      expect(described_class.edit_command('a.md', line: 12, editor: 'hx')).to eq(['hx', 'a.md:12'])
      expect(described_class.edit_command('a.md', line: 12, editor: 'code')).to eq(['code', '--wait', '-g', 'a.md:12'])
      expect(described_class.edit_command('a.md', line: 12, editor: 'code --wait')).to eq(['code', '--wait', '-g', 'a.md:12'])
    end
  end
end
