# frozen_string_literal: true

require_relative '../raindown'
require_relative 'rewriter'

module Raindown
  # Writes back to one project's Markdown files as they're saved, like its TOCs, tables and endpoint responses,
  # with the project's own nodes. Each line it shows starts with the project's name.
  class ProjectWorker
    attr_reader :root, :name

    def initialize(root:, name: File.basename(root), bare: false, execute: false)
      @root = root
      @name = name
      @bare = bare
      @execute = execute
    end

    # Loads the project's nodes from its .raindown folder.
    def start
      Nodes.load(File.join(root, Nodes::FOLDER))
    rescue StandardError, ScriptError => e
      raise if ENV['RAINDOWN_DEBUG']

      warn "[#{name}] raindown: #{Nodes::FOLDER}: #{e.message}"
    end

    # Writing back saves the file again, and that save changes nothing, so it ends there.
    def update(path)
      changed = Rewriter.update(path:, bare: @bare, execute: @execute, metadata: Pages.for(path))
      puts "[#{name}] Updated #{relative(path)}" if changed
    rescue StandardError => e
      raise if ENV['RAINDOWN_DEBUG']

      # An error in the file is shown rather than stopping the watcher, so it can be fixed and saved again.
      warn "[#{name}] raindown: #{relative(path)}: #{e.message}"
    end

    # Workers in this process have nothing to stop, unlike a ForkedWorker's process.
    def stop; end

    private

    def relative(path)
      File.expand_path(path).delete_prefix(File.join(root, ''))
    end
  end
end
