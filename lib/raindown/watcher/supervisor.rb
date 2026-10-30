# frozen_string_literal: true

require_relative '../projects'
require_relative '../workers/workers'
require_relative 'changes'
require_relative 'project'

module Raindown
  module Watcher
    # Watches every Raindown project in a directory, like ~/dev, and writes back to each Markdown file as it's saved.
    #
    # Each project's nodes load in a process of its own, forked once the shared code has loaded, so starting a project
    # costs almost nothing and two projects can have nodes of the same name. One listener watches the directory and
    # sends each changed file to its project's process. Without fork, as on Windows, the projects share this process.
    class Supervisor
      attr_reader :directory, :workers

      def initialize(directory:, bare: false, execute: false)
        @directory = File.expand_path(directory)
        @workers = Workers.new(root: @directory, fork: fork?, quiet: false) do |root|
          Project.new(root:, name: name(root), bare:, execute:).tap(&:start)
        end
        @queues = {}
      end

      def start
        $stdout.sync = true
        preload

        projects = Projects.roots(directory).each { workers[it].start }
        puts "Watching #{projects.size} #{projects.size == 1 ? 'project' : 'projects'} in #{directory} for changes..."

        trap_interrupt
        Watcher.listen(directory) { handle(it) }.start
        sleep
      ensure
        stop
      end

      # Sends each saved file to its project, starting a worker for a new project, or restarting one when its nodes
      # change. With fork, each project takes its changes in order in a thread of its own, so a slow write-back, like an
      # endpoint's request with -x, only holds up its own project. Without fork, the projects share this process, so
      # they're taken in turn.
      def handle(paths)
        Watcher.changes(paths).each do |change|
          next unless change.nodes? || change.saved?
          next take(change) unless fork?

          queue(change.root) << change
        end
      end

      def stop
        @queues.each_value(&:close)
        workers.stop
      end

      private

      # The project's changes still to take, by the thread that takes them, until the queue's closed.
      def queue(root)
        @queues[root] ||= Thread::Queue.new.tap do |queue|
          Thread.new { while (change = queue.pop) do take(change) end }
        end
      end

      # An error, like a worker stopping partway from a crash, is shown, and the project takes its next change, its
      # worker starting again.
      def take(change)
        return restart(change.root) if change.nodes?

        workers[change.root].call(:update, change.path)
      rescue StandardError => e
        warn "[#{name(change.root)}] raindown: #{e.message}"
      end

      # Without fork the projects share this process, where nodes can't be unloaded.
      def restart(root)
        return warn("[#{name(root)}] Restart raindown to load the node changes") unless fork?
        return unless workers.restart(root)

        puts "[#{name(root)}] Reloading nodes"
        workers[root].start
      end

      # A project in the directory is named by its path from there, and the project the directory is in by its folder.
      def name(root)
        return File.basename(root) unless root.start_with?(File.join(directory, ''))

        root.delete_prefix(File.join(directory, ''))
      end

      # Loaded before forking, so every project's process shares them instead of loading its own.
      def preload
        return unless fork?

        require 'lownode'
        require 'dirload'
      end

      def fork?
        Process.respond_to?(:fork)
      end

      # Ctrl+C reaches every process in the terminal, so the workers stop with the watcher.
      def trap_interrupt
        trap('INT') { exit }
      end
    end
  end
end
