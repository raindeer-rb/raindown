# frozen_string_literal: true

require_relative '../raindown'
require_relative 'formatter'

module Raindown
  class Watcher
    attr_reader :path, :output, :bare

    def initialize(path:, output: nil, bare: false)
      @path = path
      @output = output || default_output
      @bare = bare
    end

    def start
      require 'listen'

      $stdout.sync = true

      Formatter.update(path:, bare:)
      render
      puts "Watching #{path} for changes (writing to #{output})..."

      listener.start
      sleep
    end

    private

    def listener
      directory = File.dirname(File.expand_path(path))
      filename = File.basename(path)

      Listen.to(directory) do |modified, added, _removed|
        next unless (modified + added).any? { |f| File.basename(f) == filename }
        # Formatting saves the file again, and that change triggers the render.
        next if Formatter.update(path:, bare:)

        render
        puts "Re-rendered #{path} -> #{output}"
      end
    end

    def render
      File.write(output, Raindown.render_file(path:, bare:))
    end

    def default_output
      "#{File.dirname(path)}/#{File.basename(path, '.*')}.html"
    end
  end
end
