# frozen_string_literal: true

require_relative '../raindown'
require_relative 'rewriter'

module Raindown
  # Watches one file and writes back to it as it's saved, like its TOC, tables and endpoint responses.
  class Watcher
    attr_reader :path, :bare, :execute

    def initialize(path:, bare: false, execute: false)
      @path = path
      @bare = bare
      @execute = execute
    end

    def start
      require 'listen'

      $stdout.sync = true

      safely { rewrite }
      puts "Watching #{path} for changes..."

      listener.start
      sleep
    end

    private

    def listener
      directory = File.dirname(File.expand_path(path))
      filename = File.basename(path)

      Listen.to(directory) do |modified, added, _removed|
        next unless (modified + added).any? { |f| File.basename(f) == filename }

        # Writing back saves the file again, and that save changes nothing, so it ends there.
        safely { puts "Updated #{path}" if rewrite }
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
  end
end
