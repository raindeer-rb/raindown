# frozen_string_literal: true

require_relative '../projects'

module Raindown
  module Watcher
    # Listening skips these folders as they hold dependencies and builds, which Projects ignores too.
    IGNORE = %r{(?:\A|/)(?:#{Projects::IGNORED.join('|')})/}

    # A change to a project's nodes, or to one of its Markdown files, which is written back when it's been saved.
    Change = Data.define(:root, :path, :nodes) do
      def nodes? = nodes
      def saved? = !nodes && File.exist?(path)
    end

    # A listener, still to start, that gives the block the paths saved, added or removed in the directory.
    def self.listen(directory, &)
      require 'listen'
      Listen.to(directory, ignore: IGNORE) { |modified, added, removed| yield(modified + added + removed) }
    end

    # The changes among the paths, by the project each is in, the nearest one above it, or else the root, when there is
    # one, leaving out files that are neither nodes nor Markdown, or are in ignored folders.
    def self.changes(paths, root: nil)
      paths.filter_map do |path|
        project = Projects.root(path) || root || next
        next Change.new(root: project, path:, nodes: true) if Projects.node?(path, root: project)

        Change.new(root: project, path:, nodes: false) if Projects.markdown?(path, root: project)
      end
    end
  end
end
