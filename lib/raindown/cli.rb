# frozen_string_literal: true

require 'fileutils'
require 'trees'
require_relative '../raindown'
require_relative '../version'
require_relative 'rewriter'
require_relative 'watcher/file_watcher'
require_relative 'watcher/supervisor'

module Raindown
  module CLI
    extend Trees

    USAGE = <<~TEXT
      Usage: raindown [PATH] [options]
             raindown watch [PATH] [options]
             raindown FILE --html [OUTPUT] [options]
             raindown init [DIRECTORY]

      Opens PATH (default: current directory) in the terminal UI: browse a project's files and outlines, fold
      directives, run endpoints, open the editor at a line and see a dashboard of the project's charts. While it's open,
      it watches the folder and writes back to its Markdown files as they're saved, like their tables of contents.

      Commands:
        watch [PATH]        Watch PATH without the terminal UI, writing back to its Markdown files as they're saved.
                            PATH is a file, or a directory (default: current directory) whose projects with a
                            .raindown folder are watched
        init [DIRECTORY]    Create a .raindown folder for the project's config and nodes (default: current directory)

      Options:
        --html [OUTPUT]     Render FILE to HTML once, writing to OUTPUT or else printing to stdout
        --stdin             Render Markdown from stdin to HTML once, without formatting FILE, which only needs
                            its extension (to allow bare directives) and can be unsaved. Add --html OUTPUT to write a file
        --bare              Allow bare directives like :toc in Markdown files
        -x, --execute       Run endpoint curl snippets that have no output yet, as files are written back
        -h, --help          Show this message
        -v, --version       Show the version

      Set RAINDOWN_DEBUG=1 to show where an error happened.
    TEXT

    CONFIG = <<~YAML
      # Raindown project settings. See https://raindown.dev/docs/config
      #
      # Show directives as HTML comments rather than in bold:
      # hide_directives: true
      #
      # Leave code blocks unhighlighted, so the browser can highlight them instead:
      # highlight_code: false
    YAML

    # A path opens the terminal UI, or after "watch" it's watched, and with --html or --stdin it's rendered. The flags
    # are keyword arguments, in any order, like -x for x:, and --html is the OUTPUT when it's given one.
    line(':path') do |path, html: nil, stdin: false, bare: false, execute: false, x: false| # rubocop:disable Metrics/ParameterLists -- each keyword is a flag
      execute { open_path(path, html:, stdin:, bare:, execute: execute || x) }
    end

    line('watch :path') do |path, bare: false, execute: false, x: false|
      execute { watch(path, bare:, execute: execute || x) }
    end

    def self.run(argv)
      return if command(argv)

      # Without a path, like "raindown", "raindown -x" or "raindown watch", it's the current directory.
      argv = ['watch', '.', *argv.drop(1)] if argv.first == 'watch' && (argv.size == 1 || argv[1].start_with?('-'))
      argv = ['.', *argv] if argv.empty? || argv.first.start_with?('-')

      super || abort("Unknown arguments: #{argv.join(' ')}\n\n#{USAGE}")
    rescue StandardError => e
      report(e, path: argv.first)
    end

    # The :path line would match help, version and init as the file, so they're checked first.
    # Returns true when argv was one of them.
    def self.command(argv)
      abort(USAGE) if argv.intersect?(%w[-h --help])

      if argv.intersect?(%w[-v --version]) then puts(VERSION)
      elsif argv.first == 'init' && argv.size <= 2 then init(argv[1])
      else return false
      end

      true
    end

    # Shows an error in a file as one line, rather than a backtrace, unless RAINDOWN_DEBUG is set.
    def self.report(error, path:)
      raise error if ENV['RAINDOWN_DEBUG']

      abort("raindown: #{path}: #{error.message}")
    end

    # Creates the .raindown folder that marks a project's root and holds its config.yml and nodes.
    def self.init(directory = nil)
      folder = File.join(directory || Dir.pwd, Nodes::FOLDER)
      config = File.join(folder, Config::FILE)
      return puts("#{config} already exists") if File.exist?(config)

      FileUtils.mkdir_p(folder)
      File.write(config, CONFIG)
      puts "Created #{config}"
      puts 'Put your own nodes in the same folder. See https://raindown.dev/docs/nodes'
    end

    # The terminal UI loads curses, so it's only required when it starts. Without a terminal, the path's watched instead.
    def self.tui(path, bare: false, execute: false)
      abort("File not found: #{path}") unless File.exist?(path)

      require_relative 'tui'
      TUI.start(path, bare:, execute:) || watch(path, bare:, execute:)
    end

    class << self
      private

      # Endpoints run while formatting, which --stdin skips, so -x can't go with it.
      def open_path(path, html:, stdin:, bare:, execute:)
        output = html unless html == true
        abort("-x runs endpoints as the file's formatted, which --stdin doesn't do\n\n#{USAGE}") if stdin && execute
        return render_stdin(path, output, bare:) if stdin
        return render(path, output, bare:, execute:) if html

        tui(path, bare:, execute:)
      end

      def render(path, output = nil, bare: false, execute: false)
        ensure_exists(path)
        abort('--html renders a file, not a directory') if File.directory?(path)
        Nodes.load(path)

        metadata = Pages.for(path)
        Rewriter.update(path:, bare:, execute:, metadata:)
        write(output, Raindown.render_file(path:, bare:, metadata:))
      end

      def render_stdin(path, output = nil, bare: false, **)
        Nodes.load(path)
        write(output, Raindown.render(markdown: $stdin.read, metadata: Pages.for(path), bare: bare || BareDirectives.file?(path),
                                      **Config.render_options(path)))
      end

      # Watching only writes back to the files, while --html and --stdin render HTML.
      def watch(path, bare: false, execute: false)
        ensure_exists(path)
        return Watcher::Supervisor.new(directory: path, bare:, execute:).start if File.directory?(path)

        Nodes.load(path)
        Watcher::FileWatcher.new(path:, bare:, execute:).start
      end

      def write(output, html)
        output ? File.write(output, html) : puts(html)
      end

      def ensure_exists(path)
        abort("File not found: #{path}") unless File.exist?(path)
      end
    end
  end
end
