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
        -h, --help          Show this message
    TEXT

    line('render :path') do |path|
      execute { render(path) }

      ['--output', '-o'].each do |flag|
        line("#{flag} :output") do |path, output|
          execute { render(path, output) }
        end
      end
    end

    line('watch :path') do |path|
      execute { watch(path) }

      ['--output', '-o'].each do |flag|
        line("#{flag} :output") do |path, output|
          execute { watch(path, output) }
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

      def render(path, output = nil)
        ensure_exists(path)

        Formatter.update(path:)
        write(output, render_file(path))
      end

      def watch(path, output = nil)
        ensure_exists(path)

        Watcher.new(path:, output:).start
      end

      def ensure_exists(path)
        abort("File not found: #{path}") unless File.exist?(path)
      end

      def render_file(path)
        Raindown.render(markdown: File.read(path))
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
