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
        -h, --help          Show this message
    TEXT

    OUTPUT_FLAGS = ['--output', '-o'].freeze

    # Trees matches tokens in order, so --bare is accepted before or after the output flag.
    %i[render watch].each do |command|
      line("#{command} :path") { |path| execute { send(command, path) } }
      line("#{command} :path --bare") { |path| execute { send(command, path, bare: true) } }

      OUTPUT_FLAGS.each do |flag|
        line("#{command} :path #{flag} :output") { |path, output| execute { send(command, path, output) } }
        line("#{command} :path #{flag} :output --bare") { |path, output| execute { send(command, path, output, bare: true) } }
        line("#{command} :path --bare #{flag} :output") { |path, output| execute { send(command, path, output, bare: true) } }
      end
    end

    line('-h') { execute { abort(USAGE) } }
    line('--help') { execute { abort(USAGE) } }

    def self.run(argv)
      super || abort("Unknown command: #{argv.join(' ')}\n\n#{USAGE}")
    end

    class << self
      private

      def render(path, output = nil, bare: false)
        ensure_exists(path)

        Formatter.update(path:, bare:)
        write(output, Raindown.render_file(path:, bare:))
      end

      def watch(path, output = nil, bare: false)
        ensure_exists(path)

        Watcher.new(path:, output:, bare:).start
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
