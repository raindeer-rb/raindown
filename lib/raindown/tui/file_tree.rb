# frozen_string_literal: true

require_relative '../projects'
require_relative 'row'

module Raindown
  module TUI
    # The files pane: a project's Markdown files as a tree, with folders before files, where folders fold.
    class FileTree
      attr_reader :root

      def initialize(root:)
        @root = root
        @folded = Set.new
        load
      end

      def load
        @files = Projects.files(root)
      end

      def rows
        tree = {}
        @files.each { |path| relative(path).split('/').reduce(tree) { |node, part| node[part] ||= {} } }
        tree_rows(tree, '', 0)
      end

      def toggle(folder)
        @folded.delete?(folder) || @folded.add(folder)
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
        folded = @folded.include?(folder)
        row = Row.new(text: "#{folded ? '▸' : '▾'} #{name}/", depth:, kind: :folder, target: folder)

        [row, *(tree_rows(children, File.join(prefix, name), depth + 1) unless folded)]
      end
    end
  end
end
