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

  let(:supervisor) { instance_double(Raindown::Supervisor, start: nil) }

  before do
    allow(Raindown::Watcher).to receive(:new).and_return(watcher)
    allow(Raindown::Supervisor).to receive(:new).and_return(supervisor)
  end

  describe '.run' do
    it 'watches the file' do
      described_class.run(['watch', path])

      expect(Raindown::Watcher).to have_received(:new).with(path:, bare: false, execute: false)
      expect(watcher).to have_received(:start)
    end

    it 'accepts the options in any order' do
      [['--bare', '-x'], ['--execute', '--bare']].each { |args| described_class.run(['watch', path, *args]) }

      expect(Raindown::Watcher).to have_received(:new).with(path:, bare: true, execute: true).twice
    end

    it 'watches the projects in a directory' do
      described_class.run(['watch', @dir, '-x'])

      expect(Raindown::Supervisor).to have_received(:new).with(directory: @dir, bare: false, execute: true)
      expect(supervisor).to have_received(:start)
    end

    it 'watches the current directory without a path' do
      [[], ['--bare']].each { |args| described_class.run(['watch', *args]) }

      expect(Raindown::Supervisor).to have_received(:new).with(directory: '.', bare: false, execute: false)
      expect(Raindown::Supervisor).to have_received(:new).with(directory: '.', bare: true, execute: false)
    end

    it 'aborts when --html is given a directory' do
      expect { described_class.run([@dir, '--html']) }.to raise_error(SystemExit).and output(/not a directory/).to_stderr
    end

    context 'with --html' do
      it 'renders to stdout without watching' do
        File.write(path, "# Title\n\n<{ toc: }>\n<{ :toc }>\n\n## Section\n")

        expect { described_class.run([path, '--html']) }.to output(/Table of contents/).to_stdout
        expect(File.read(path)).to include('- [Section](#section)')
        expect(Raindown::Watcher).not_to have_received(:new)
      end

      it 'writes to the given output path with the other options in any order' do
        rd = File.join(@dir, 'sample.rd').tap { |file| File.write(file, "# Title\n\n:toc\n") }

        [['--html', output_path], ['-x', '--html', output_path, '--bare'], ['--bare', '--html', output_path, '-x']].each do |args|
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
        run_with_stdin("# Title\n", [path, '--stdin', '--html', output_path])

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

    it 'shows an error in the file as one line' do
      File.write(path, "# Title\n\n<{ toc: }>\n")

      expect { described_class.run([path, '--html']) }
        .to raise_error(SystemExit).and output("raindown: #{path}: <{ toc: }> on line 3 needs <{ :toc }>\n").to_stderr
    end

    it 'shows where an error happened with RAINDOWN_DEBUG' do
      File.write(path, "# Title\n\n<{ toc: }>\n")
      stub_const('ENV', ENV.to_h.merge('RAINDOWN_DEBUG' => '1'))

      expect { described_class.run([path, '--html']) }.to raise_error(Raindown::NodeBlocks::MissingEndTag)
    end

    it 'shows the version with -v or --version' do
      [['-v'], ['--version']].each do |args|
        expect { described_class.run(args) }.to output("#{Raindown::VERSION}\n").to_stdout
      end
    end

    describe 'init' do
      let(:config) { File.join(@dir, '.raindown', 'config.yml') }

      it 'creates a .raindown folder with a config file in the current directory' do
        Dir.chdir(@dir) { expect { described_class.run(['init']) }.to output(/Created .*config\.yml/).to_stdout }

        expect(File.read(config)).to include('# hide_directives: true')
        expect(Raindown::Config.for(path)).to eq(Raindown::Config::DEFAULTS)
      end

      it 'creates it in the given directory' do
        expect { described_class.run(['init', @dir]) }.to output(/Created/).to_stdout

        expect(File).to exist(config)
      end

      it 'keeps an existing config file' do
        FileUtils.mkdir_p(File.dirname(config))
        File.write(config, "hide_directives: true\n")

        expect { described_class.run(['init', @dir]) }.to output(/already exists/).to_stdout
        expect(File.read(config)).to eq("hide_directives: true\n")
      end
    end

    describe 'tui' do
      before do
        require 'raindown/tui'
        allow(Raindown::TUI).to receive(:start)
      end

      it 'starts the terminal UI on the path, or the current directory, rather than watching' do
        described_class.run([path])
        expect(Raindown::TUI).to have_received(:start).with(path)

        described_class.run([])
        expect(Raindown::TUI).to have_received(:start).with('.')
        expect(Raindown::Watcher).not_to have_received(:new)
        expect(Raindown::Supervisor).not_to have_received(:new)
      end

      it "leaves watching's options to watch" do
        expect { described_class.run(['-x']) }.to raise_error(SystemExit).and output(/Unknown arguments: \. -x/).to_stderr
        expect(Raindown::TUI).not_to have_received(:start)
      end

      it 'stops when the path does not exist' do
        expect { described_class.run(%w[missing.md]) }.to raise_error(SystemExit).and output(/File not found/).to_stderr
        expect(Raindown::TUI).not_to have_received(:start)
      end
    end

    it 'shows the usage with -h or --help' do
      [['-h'], ['--help'], [path, '--help']].each do |args|
        expect { described_class.run(args) }.to raise_error(SystemExit).and output(/Usage: raindown \[PATH\]/).to_stderr
      end

      expect(Raindown::Watcher).not_to have_received(:new)
    end
  end
end
