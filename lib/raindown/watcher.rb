# frozen_string_literal: true

require_relative '../raindown'
require_relative 'rewriter'

module Raindown
  class Watcher
    attr_reader :path, :output, :bare, :execute

    def initialize(path:, output: nil, bare: false, execute: false)
      @path = path
      @output = output || default_output
      @bare = bare
      @execute = execute
    end

    def start
      require 'listen'

      $stdout.sync = true

      safely do
        rewrite
        render
      end
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

        safely do
          # Formatting saves the file again, and that change triggers the render.
          next if rewrite

          render
          puts "Re-rendered #{path} -> #{output}"
        end
      end
    end

    # An error in the file is shown rather than stopping the watcher, so it can be fixed and saved again.
    def safely
      yield
    rescue StandardError => e
      raise if ENV['RAINDOWN_DEBUG']

      warn "raindown: #{path}: #{e.message}"
    end

    # The files' metadata is loaded again each time, so new and renamed files are listed.
    def rewrite
      Rewriter.update(path:, bare:, execute:, metadata: Pages.for(path))
    end

    def render
      File.write(output, Raindown.render_file(path:, bare:, metadata: Pages.for(path)))
    end

    def default_output
      "#{File.dirname(path)}/#{File.basename(path, '.*')}.html"
    end
  end
end
