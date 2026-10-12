# frozen_string_literal: true

require 'trees'
require_relative '../raindown'
require_relative 'formatter'
require_relative 'watcher'

module Raindown
  module CLI
    extend Trees

    USAGE = <<~TEXT
      Usage: raindown COMMAND FILE [options]

      Commands:
        render   Render FILE once and print (or write) the HTML output
        watch    Re-render FILE every time it is saved

      Options:
        -o, --output PATH   Write output to PATH instead of stdout
        --bare              Allow bare directives like :toc in Markdown files
        -x, --execute       Run endpoint curl snippets that have no output yet
        -h, --help          Show this message
    TEXT

    OPTIONS = { output: ['-o :output', '--output :output'], bare: ['--bare'], execute: ['-x', '--execute'] }.freeze

    # Trees matches tokens in order, so there's a line for every order and spelling of the options.
    OPTION_LINES = (0..OPTIONS.size).flat_map { |count| OPTIONS.keys.permutation(count).to_a }.flat_map do |names|
      [[]].product(*names.map { |name| OPTIONS[name] }).map { |flags| [names, flags.flatten] }
    end

    %i[render watch].each do |command|
      OPTION_LINES.each do |names, flags|
        options = { bare: names.include?(:bare), execute: names.include?(:execute) }
        pattern = ["#{command} :path", *flags].join(' ')

        if names.include?(:output)
          line(pattern) { |path, output| execute { send(command, path, output, **options) } }
        else
          line(pattern) { |path| execute { send(command, path, **options) } }
        end
      end
    end

    line('-h') { execute { abort(USAGE) } }
    line('--help') { execute { abort(USAGE) } }

    def self.run(argv)
      super || abort("Unknown command: #{argv.join(' ')}\n\n#{USAGE}")
    end

    class << self
      private

      def render(path, output = nil, bare: false, execute: false)
        ensure_exists(path)

        Formatter.update(path:, bare:, execute:)
        write(output, Raindown.render_file(path:, bare:))
      end

      def watch(path, output = nil, bare: false, execute: false)
        ensure_exists(path)

        Watcher.new(path:, output:, bare:, execute:).start
      end

      def ensure_exists(path)
        abort("File not found: #{path}") unless File.exist?(path)
      end

      def write(output, html)
        if output
          File.write(output, html)
        else
          puts html
        end
      end
    end
  end
end
