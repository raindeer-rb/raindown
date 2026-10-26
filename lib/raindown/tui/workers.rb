# frozen_string_literal: true

require_relative '../projects'
require_relative 'worker'

module Raindown
  module TUI
    # A Worker for each project in the terminal UI's folder: the folder's own, and every project inside it.
    # A file's requests go to the worker of the project it's in, the nearest one above it, even when it's new.
    # Workers start when they're first asked something.
    class Workers
      attr_reader :root, :roots

      def initialize(root:, fork: Worker.fork?)
        @root = root
        @fork = fork
        @workers = {}
        find_roots
      end

      def for(path)
        worker(Projects.root(path) || root)
      end

      # A worker for each project, as they were found when the workers last started.
      def each(&)
        roots.map { worker(it) }.each(&)
      end

      # Stops the workers, so the next requests start them again, loading their projects' nodes again,
      # and finds the projects again, like ones added since.
      def restart
        stop
        @workers.clear
        find_roots
      end

      def stop
        @workers.each_value(&:stop)
      end

      private

      def worker(project)
        @workers[project] ||= Worker.new(root: project, fork: @fork)
      end

      def find_roots
        @roots = [root, *Projects.roots(root)].uniq.sort
      end
    end
  end
end
