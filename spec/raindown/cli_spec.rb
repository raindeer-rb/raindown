# frozen_string_literal: true

require 'raindown/cli'
require 'tmpdir'

RSpec.describe Raindown::CLI do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  let(:path) { File.join(@dir, 'sample.md').tap { |file| File.write(file, "# Title\n") } }
  let(:output_path) { File.join(@dir, 'out.html') }
  let(:watcher) { instance_double(Raindown::Watcher, start: nil) }

  before { allow(Raindown::Watcher).to receive(:new).and_return(watcher) }

  describe '.run' do
    it 'watches the file' do
      described_class.run([path])

      expect(Raindown::Watcher).to have_received(:new).with(path:, output: nil, bare: false, execute: false)
      expect(watcher).to have_received(:start)
    end

    it 'writes to the given output path' do
      described_class.run([path, '-o', output_path])
      described_class.run([path, '--output', output_path])

      expect(Raindown::Watcher).to have_received(:new).with(path:, output: output_path, bare: false, execute: false).twice
    end

    it 'accepts the options in any order' do
      [['--bare', '-x', '-o', output_path], ['-o', output_path, '--execute', '--bare'], ['-x', '--output', output_path, '--bare']]
        .each { |args| described_class.run([path, *args]) }

      expect(Raindown::Watcher).to have_received(:new).with(path:, output: output_path, bare: true, execute: true).thrice
    end

    context 'with --once' do
      it 'renders to stdout without watching' do
        File.write(path, "# Title\n\n<{ :toc }>\n\n## Section\n")

        expect { described_class.run([path, '--once']) }.to output(/Table of contents/).to_stdout
        expect(File.read(path)).to include('- [Section](#section)')
        expect(Raindown::Watcher).not_to have_received(:new)
      end

      it 'writes to the given output path with the other options in any order' do
        rd = File.join(@dir, 'sample.rd').tap { |file| File.write(file, "# Title\n\n:toc\n") }

        [['--once', '-o', output_path], ['-x', '--output', output_path, '--once', '--bare']].each do |args|
          File.delete(output_path) if File.exist?(output_path)
          described_class.run([rd, *args])

          expect(File.read(output_path)).to include('Table of contents')
        end
      end
    end

    context 'with --stdin' do
      def run_with_stdin(markdown, args)
        allow($stdin).to receive(:read).and_return(markdown)
        described_class.run(args)
      end

      it 'renders stdin without formatting the file' do
        expect { run_with_stdin("# Title\n\n<{ :toc }>\n\n## Section\n", [path, '--stdin']) }
          .to output(/Table of contents.*Section/m).to_stdout
        expect(File.read(path)).to eq("# Title\n")
        expect(Raindown::Watcher).not_to have_received(:new)
      end

      it 'allows bare directives by the extension of a file that does not exist' do
        markdown = "# Title\n\n:toc\n"

        expect { run_with_stdin(markdown, [File.join(@dir, 'unsaved.rd'), '--stdin']) }.to output(/Table of contents/).to_stdout
        expect { run_with_stdin(markdown, [File.join(@dir, 'unsaved.md'), '--stdin']) }
          .not_to output(/Table of contents/).to_stdout
        expect { run_with_stdin(markdown, [File.join(@dir, 'unsaved.md'), '--bare', '--stdin']) }
          .to output(/Table of contents/).to_stdout
      end

      it 'writes to the given output path' do
        run_with_stdin("# Title\n", [path, '--stdin', '-o', output_path])

        expect(File.read(output_path)).to include('Title')
      end

      it 'does not run endpoints' do
        expect { run_with_stdin("# Title\n", [path, '--stdin', '-x']) }
          .to raise_error(SystemExit).and output(/Unknown arguments/).to_stderr
      end
    end

    it 'aborts when the file does not exist' do
      expect { described_class.run([File.join(@dir, 'missing.md')]) }
        .to raise_error(SystemExit).and output(/File not found/).to_stderr
    end

    it 'shows the usage with -h, --help or no arguments' do
      [['-h'], ['--help'], [], [path, '--help']].each do |args|
        expect { described_class.run(args) }.to raise_error(SystemExit).and output(/Usage: raindown FILE/).to_stderr
      end

      expect(Raindown::Watcher).not_to have_received(:new)
    end
  end
end
