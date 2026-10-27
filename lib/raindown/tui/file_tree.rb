# frozen_string_literal: true

require_relative '../projects'
require_relative 'events'
require_relative 'views/outline_view'
require_relative 'row'

module Raindown
  module TUI
    # The nav pane's files: a project's Markdown files as a tree, with folders before files,
    # including the files of the projects inside it, whose folders are marked with Raindown's cloud.
    # Folders start folded, and open with Enter, or when a file in them opens.
    # A scope narrows it to one project's own files, from the project's folder, like when it's chosen in the header.
    class FileTree
      attr_reader :root
      # The project the files are narrowed to, or nil for all of them.
      attr_accessor :scope

      def initialize(root:, workers:)
        @root = root
        @workers = workers
        @expanded = Set.new
        load
      end

      # The rain cloud without its emoji variation selector, which every terminal draws one column wide, so it lines up
      # the files with the panes beside them. With the selector, as in the title, some terminals draw it two.
      PROJECT = '🌧'

      def load
        @files = Projects.files(root, nested: true)
        @projects = Projects.roots(root).to_set
      end

      # The folder the tree starts from: the scope's, or the root's.
      def base = scope || root

      def rows
        tree = {}
        files.each { |path| relative(path).split('/').reduce(tree) { |node, part| node[part] ||= {} } }
        tree_rows(tree, '', 0)
      end

      def toggle(folder)
        @expanded.delete?(folder) || @expanded.add(folder)
      end

      # Opens the folders the file is in, so its row is shown.
      def reveal(path)
        folder = File.dirname(path)
        while folder.start_with?(File.join(root, ''))
          @expanded.add(folder)
          folder = File.dirname(folder)
        end
      end

      def relative(path)
        path.delete_prefix(File.join(base, ''))
      end

      private

      # A scope's own files, without those of the projects inside it, which are projects of their own.
      def files
        return @files unless scope

        @files.select { |path| owner(path) == scope }
      end

      def owner(path)
        [root, *@projects].select { path.start_with?(File.join(it, '')) }.max_by(&:length)
      end

      def tree_rows(tree, prefix, depth)
        folders, files = tree.partition { |_name, children| children.any? }

        folders.sort.flat_map { |name, children| folder_rows(name, children, prefix, depth) } +
          files.sort.map { |name, _| file_row(name, File.join(base, prefix, name), depth) }
      end

      def file_row(name, path, depth)
        Row.new(text: name, depth:, kind: :file, target: path, open: OpenView.new(view: OutlineView.new(path, workers: @workers)))
      end

      # A folder, and the tree inside it unless it's folded.
      def folder_rows(name, children, prefix, depth)
        folder = File.join(base, prefix, name)
        folded = !@expanded.include?(folder)
        project = @projects.include?(folder)
        row = Row.new(text: "#{folded ? '▸' : '▾'} #{"#{PROJECT} " if project}#{name}/", depth:,
                      kind: project ? :project : :folder, target: folder, fold: -> { toggle(folder) })

        [row, *(tree_rows(children, File.join(prefix, name), depth + 1) unless folded)]
      end
    end
  end
end
