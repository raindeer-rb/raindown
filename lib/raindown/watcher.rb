# frozen_string_literal: true

require_relative '../raindown'
require_relative 'toc_injector'

module Raindown
  class Watcher
    attr_reader :path, :output

    def initialize(path:, output: nil)
      @path = path
      @output = output || default_output
    end

    def start
      require 'listen'

      $stdout.sync = true

      TOCInjector.update(path:)
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
        # Updating the TOC saves the file again, and that change triggers the render.
        next if TOCInjector.update(path:)

        render
        puts "Re-rendered #{path} -> #{output}"
      end
    end

    def render
      File.write(output, Raindown.render(markdown: File.read(path)))
    end

    def default_output
      "#{File.dirname(path)}/#{File.basename(path, '.*')}.html"
    end
  end
end
