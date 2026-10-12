# frozen_string_literal: true

require 'raindown/cli'
require 'tmpdir'
require 'stringio'

RSpec.describe Raindown::CLI do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  def write_markdown(content, name: 'sample.md')
    path = File.join(@dir, name)
    File.write(path, content)
    path
  end

  def silence
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end

  describe '.run' do
    it 'renders a file to stdout by default' do
      path = write_markdown("# Title\n\n<{ :toc }>\n\n## Section\n")

      expect { described_class.run(['render', path]) }.to output(/Table of contents/).to_stdout
    end

    it 'renders bare directives in Raindown files' do
      path = write_markdown("# Title\n\n:toc\n\n## Section\n", name: 'sample.rd')

      expect { described_class.run(['render', path]) }.to output(/Table of contents/).to_stdout
      expect(File.read(path)).to include("\n:toc\n\n<!-- raindown:toc -->\n")
    end

    it 'renders bare directives in Markdown files with --bare' do
      path = write_markdown("# Title\n\n:toc\n\n## Section\n")

      expect { described_class.run(['render', path]) }.not_to output(/Table of contents/).to_stdout
      expect { described_class.run(['render', path, '--bare']) }.to output(/Table of contents/).to_stdout
    end

    it 'accepts --bare before or after the output flag' do
      path = write_markdown("# Title\n\n:toc\n")
      output = File.join(@dir, 'sample.html')

      [['--bare', '-o', output], ['-o', output, '--bare'], ['--output', output, '--bare']].each do |args|
        File.delete(output) if File.exist?(output)
        described_class.run(['render', path, *args])

        expect(File.read(output)).to include('Table of contents')
      end
    end

    it 'runs endpoints with -x or --execute' do
      allow(Raindown::Curl).to receive(:run).and_return(['{}', 'json'])
      output = File.join(@dir, 'sample.html')

      [['-x'], ['--execute', '-o', output], ['-o', output, '--bare', '-x']].each do |args|
        path = write_markdown("<{ endpoint: :later }>\n\n```sh\ncurl https://api.example.com\n```\n")
        silence { described_class.run(['render', path, *args]) }

        expect(File.read(path)).to end_with("```\n\n```json\n{}\n```\n")
      end
    end

    it 'writes rendered output to the given path' do
      path = write_markdown("# Title\n\n<{ :toc }>\n\n## Section\n")
      output = File.join(@dir, 'sample.html')

      described_class.run(['render', path, '-o', output])

      expect(File.read(output)).to include('Table of contents')
    end

    it 'updates the Markdown TOC when rendering' do
      path = write_markdown("# Title\n\n<{ :toc }>\n\n## Section\n")
      output = File.join(@dir, 'sample.html')

      described_class.run(['render', path, '-o', output])

      expect(File.read(path)).to include('- [Section](#section)')
      expect(File.read(output)).not_to include('raindown:toc')
    end

    it 'aligns Markdown tables when rendering' do
      path = write_markdown("| a | b |\n|-|-|\n| ccc | d |\n")

      expect { described_class.run(['render', path]) }.to output(/<table>/).to_stdout
      expect(File.read(path)).to eq("| a   | b   |\n| --- | --- |\n| ccc | d   |\n")
    end

    it 'renders a file without a :toc directive' do
      path = write_markdown("# Title\n")

      expect { described_class.run(['render', path]) }.to output(/Title/).to_stdout
      expect(File.read(path)).to eq("# Title\n")
    end

    it 'aborts when the file does not exist' do
      expect { described_class.run(['render', File.join(@dir, 'missing.md')]) }
        .to raise_error(SystemExit)
    end

    it 'aborts on an unknown command' do
      expect { described_class.run(['bogus']) }.to raise_error(SystemExit)
    end
  end
end
