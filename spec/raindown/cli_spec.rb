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

  def write_markdown(content)
    path = File.join(@dir, 'sample.md')
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

    it 'injects a Markdown link list beneath the :toc directive' do
      path = write_markdown("# Title\n\n<{ :toc }>\n\n## Section\n")

      silence { described_class.run(['toc', path]) }

      expect(File.read(path)).to eq(<<~MARKDOWN)
        # Title

        <{ :toc }>

        <!-- raindown:toc -->
        - [Title](#title)
          - [Section](#section)
        <!-- /raindown:toc -->

        ## Section
      MARKDOWN
    end

    it 'is idempotent when nothing has changed' do
      path = write_markdown("# Title\n\n<{ :toc }>\n\n## Section\n")

      silence { described_class.run(['toc', path]) }
      first_pass = File.read(path)
      silence { described_class.run(['toc', path]) }

      expect(File.read(path)).to eq(first_pass)
    end

    it 'updates an existing TOC block in place when headings change' do
      path = write_markdown("# Title\n\n<{ :toc }>\n\n## Section\n")

      silence { described_class.run(['toc', path]) }
      File.write(path, "#{File.read(path)}\n## New Section\n")
      silence { described_class.run(['toc', path]) }

      content = File.read(path)
      expect(content.scan('raindown:toc').length).to eq(2)
      expect(content).to include('[New Section](#new-section)')
    end

    it 'aborts when the file has no :toc directive' do
      path = write_markdown("# Title\n\n## Section\n")

      expect { described_class.run(['toc', path]) }.to raise_error(SystemExit)
    end
  end
end
