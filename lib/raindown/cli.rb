# frozen_string_literal: true

require 'trees'
require_relative '../raindown'
require_relative 'rewriter'
require_relative 'watcher'

module Raindown
  module CLI
    extend Trees

    USAGE = <<~TEXT
      Usage: raindown FILE [options]

      Renders FILE to HTML, then re-renders it every time it is saved.

      Options:
        -o, --output PATH   Write output to PATH instead of FILE.html beside FILE
        --once              Render once without watching, printing to stdout unless -o is given
        --stdin             Render Markdown from stdin once, without formatting FILE, which only needs
                            its extension (to allow bare directives) and can be unsaved
        --bare              Allow bare directives like :toc in Markdown files
        -x, --execute       Run endpoint curl snippets that have no output yet
        -h, --help          Show this message
    TEXT

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

    # The :path line would match a help flag as the file, so help is checked first.
    def self.run(argv)
      abort(USAGE) if argv.empty? || argv.intersect?(%w[-h --help])

      super || abort("Unknown arguments: #{argv.join(' ')}\n\n#{USAGE}")
    rescue StandardError => e
      report(e, path: argv.first)
    end

    # Shows an error in a file as one line, rather than a backtrace, unless RAINDOWN_DEBUG is set.
    def self.report(error, path:)
      raise error if ENV['RAINDOWN_DEBUG']

      abort("raindown: #{path}: #{error.message}")
    end
    end

    class << self
      private

      def render(path, output = nil, bare: false, execute: false)
        ensure_exists(path)
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

      def watch(path, output = nil, bare: false, execute: false)
        ensure_exists(path)
        Nodes.load(path)

        Watcher.new(path:, output:, bare:, execute:).start
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
