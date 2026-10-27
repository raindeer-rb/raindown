# frozen_string_literal: true

require_relative 'endpoint'
require_relative 'file_tree'
require_relative 'row'
require_relative 'worker'

module Raindown
  module TUI
    # Every endpoint in the projects' files, found by each project's Worker, listed below the files.
    # Like the dashboard, it can be narrowed to a project's own.
    class Endpoints
      # The project the endpoints are narrowed to, or nil for every project's.
      attr_accessor :project

      def initialize(workers:)
        @workers = workers
        load
      end

      # Finds the endpoints again, like after a file's changed.
      def load
        @endpoints = @workers.each.flat_map do |worker|
          worker.call(:endpoints)
        rescue Worker::Error
          []
        end
      end

      def all = project ? @endpoints.select { it.project == project } : @endpoints

      # Below the files, after a blank line, when there are any.
      def rows
        return [] if all.empty?

        [FileTree::SEPARATOR, *all.map { Row.new(text: it.address, tag: it, depth: 0, kind: :endpoint, target: it, open: it) }]
      end
    end
  end
end
