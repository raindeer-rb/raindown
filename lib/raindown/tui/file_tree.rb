# frozen_string_literal: true

require_relative '../projects'
require_relative 'row'

module Raindown
  module TUI
    # The files pane: the Dashboard, then a project's Markdown files as a tree, with folders before files,
    # including the files of the projects inside it.
    # Folders start folded, and open with Enter, or when a file in them opens.
    class FileTree
      # A chart, which every terminal draws two columns wide.
      DASHBOARD = Row.new(text: '📊 Dashboard', depth: 0, kind: :dashboard, target: :dashboard)

      attr_reader :root

      def initialize(root:)
        @root = root
        @expanded = Set.new
        load
      end

      def load
        @files = Projects.files(root, nested: true)
      end

      def rows
        tree = {}
        @files.each { |path| relative(path).split('/').reduce(tree) { |node, part| node[part] ||= {} } }
        [DASHBOARD, *tree_rows(tree, '', 0)]
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
        path.delete_prefix(File.join(root, ''))
      end

      private

      def tree_rows(tree, prefix, depth)
        folders, files = tree.partition { |_name, children| children.any? }

        folders.sort.flat_map { |name, children| folder_rows(name, children, prefix, depth) } +
          files.sort.map { |name, _| Row.new(text: name, depth:, kind: :file, target: File.join(root, prefix, name)) }
      end

      # A folder, and the tree inside it unless it's folded.
      def folder_rows(name, children, prefix, depth)
        folder = File.join(root, prefix, name)
        folded = !@expanded.include?(folder)
        row = Row.new(text: "#{folded ? '▸' : '▾'} #{name}/", depth:, kind: :folder, target: folder)

        [row, *(tree_rows(children, File.join(prefix, name), depth + 1) unless folded)]
      end
    end
  end
end
