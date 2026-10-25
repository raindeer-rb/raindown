# frozen_string_literal: true

require 'find'
require_relative 'nodes'
require_relative 'pages'

module Raindown
  # Raindown projects are folders with a .raindown folder, and their Markdown files are watched for changes.
  # A file belongs to the project of the nearest .raindown folder above it, so projects can sit inside each other.
  module Projects
    # Folders of dependencies, builds and tooling, which aren't searched for projects or watched, nor are hidden folders.
    IGNORED = %w[node_modules vendor tmp pkg build dist coverage].freeze

    module_function

    # The roots of the projects in a directory: the project the directory is in, if any, and every project below it.
    def roots(directory)
      directory = File.expand_path(directory)
      roots = [root(directory)].compact

      Find.find(directory) do |path|
        next unless File.directory?(path)

        Find.prune if path != directory && ignored?(File.basename(path))
        roots << path if File.directory?(File.join(path, Nodes::FOLDER))
      end

      roots.uniq
    end

    # The root of the project a file or directory is in, or nil when it isn't in one.
    def root(path)
      path = File.expand_path(path)
      folder = Nodes.find_folder(File.directory?(path) ? path : File.dirname(path))
      folder && File.dirname(folder)
    end

    # Whether a file is Markdown in its project, rather than in an ignored or hidden folder like node_modules.
    def markdown?(path, root:)
      return false unless Pages::EXTENSIONS.include?(File.extname(path).delete_prefix('.').downcase)

      folders = File.dirname(File.expand_path(path)).delete_prefix(root).split('/').reject(&:empty?)
      folders.none? { |folder| ignored?(folder) }
    end

    # Whether a file is one of a project's own nodes, which load when its watcher starts.
    def node?(path, root:)
      File.expand_path(path).start_with?(File.join(root, Nodes::FOLDER, '')) && %w[.rb .rbx].include?(File.extname(path))
    end

    def ignored?(folder)
      folder.start_with?('.') || IGNORED.include?(folder)
    end
  end
end
