# frozen_string_literal: true

require 'fileutils'
require 'trees'
require_relative '../raindown'
require_relative '../version'
require_relative 'rewriter'
require_relative 'supervisor'
require_relative 'watcher'

module Raindown
  module CLI
    extend Trees

    USAGE = <<~TEXT
      Usage: raindown [PATH] [options]
             raindown FILE --once [-o OUTPUT]
             raindown init [DIRECTORY]

      Watches PATH and writes back to its Markdown files as they're saved, like their tables of contents and tables.
      PATH is a file, or a directory (default: current directory) whose projects with a .raindown folder are watched.

      Commands:
        init [DIRECTORY]    Create a .raindown folder for the project's config and nodes (default: current directory)

      Options:
        --once              Render FILE to HTML once, printing to stdout unless -o is given
        -o, --output PATH   Write the HTML from --once or --stdin to PATH
        --stdin             Render Markdown from stdin once, without formatting FILE, which only needs
                            its extension (to allow bare directives) and can be unsaved
        --bare              Allow bare directives like :toc in Markdown files
        -x, --execute       Run endpoint curl snippets that have no output yet
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

    OPTIONS = { output: ['-o :output', '--output :output'], bare: ['--bare'], execute: ['-x', '--execute'],
                once: ['--once'], stdin: ['--stdin'] }.freeze

    # Trees matches tokens in order, so there's a line for every order and spelling of the options.
    OPTION_LINES = (0..OPTIONS.size).flat_map { |count| OPTIONS.keys.permutation(count).to_a }.flat_map do |names|
      [[]].product(*names.map { |name| OPTIONS[name] }).map { |flags| [names, flags.flatten] }
    end

    OPTION_LINES.each do |names, flags|
      # Endpoints run while formatting, which --stdin skips.
      next if names.include?(:stdin) && names.include?(:execute)

      command = if names.include?(:stdin) then :render_stdin
                elsif names.include?(:once) then :render
                else :watch
                end
      options = { bare: names.include?(:bare), execute: names.include?(:execute) }
      pattern = [':path', *flags].join(' ')

      if names.include?(:output)
        line(pattern) { |path, output| execute { send(command, path, output, **options) } }
      else
        line(pattern) { |path| execute { send(command, path, **options) } }
      end
    end

    # The :path line would match help, version and init as the file, so they're checked first.
    def self.run(argv)
      abort(USAGE) if argv.intersect?(%w[-h --help])
      return puts(VERSION) if argv.intersect?(%w[-v --version])
      return init(argv[1]) if argv.first == 'init' && argv.size <= 2

      # Without a path, like "raindown" or "raindown -x", the current directory is watched.
      argv = ['.', *argv] if argv.empty? || argv.first.start_with?('-')

      super || abort("Unknown arguments: #{argv.join(' ')}\n\n#{USAGE}")
    rescue StandardError => e
      report(e, path: argv.first)
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

    class << self
      private

      def render(path, output = nil, bare: false, execute: false)
        ensure_exists(path)
        abort('--once renders a file, not a directory') if File.directory?(path)
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

      # Watching only writes back to the files, so -o is for --once and --stdin, which render HTML.
      def watch(path, output = nil, bare: false, execute: false)
        abort('-o only works with --once or --stdin, as watching writes back to the files') if output
        ensure_exists(path)
        return Supervisor.new(directory: path, bare:, execute:).start if File.directory?(path)

        Nodes.load(path)
        Watcher.new(path:, bare:, execute:).start
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
