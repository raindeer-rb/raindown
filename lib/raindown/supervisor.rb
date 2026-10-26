# frozen_string_literal: true

require_relative 'project_worker'
require_relative 'projects'

module Raindown
  # Watches every Raindown project in a directory, like ~/dev, and writes back to each Markdown file as it's saved.
  #
  # Each project's nodes load in a process of its own, forked once the shared code has loaded, so starting a project
  # costs almost nothing and two projects can have nodes of the same name. One listener watches the directory and sends
  # each changed file to its project's process. Without fork, as on Windows, the projects share this process.
  class Supervisor
    # Watching skips these folders as they hold dependencies and builds, which Projects ignores too.
    IGNORE = %r{(?:\A|/)(?:#{Projects::IGNORED.join('|')})/}

    attr_reader :directory, :workers

    def initialize(directory:, bare: false, execute: false)
      @directory = File.expand_path(directory)
      @bare = bare
      @execute = execute
      @workers = {}
    end

    def start
      require 'listen'
      $stdout.sync = true
      preload

      Projects.roots(directory).each { worker(it) }
      puts "Watching #{workers.size} #{workers.size == 1 ? 'project' : 'projects'} in #{directory} for changes..."

      trap_interrupt
      listener.start
      sleep
    ensure
      stop
    end

    # Sends each changed file to its project, starting a worker for a new project, or restarting one when its nodes change.
    def handle(paths)
      paths.each do |path|
        root = Projects.root(path) || next

        if Projects.node?(path, root:)
          restart(root)
        elsif Projects.markdown?(path, root:)
          worker(root).update(path)
        end
      end
    end

    def stop
      workers.each_value(&:stop)
      workers.clear
    end

    private

    def listener
      Listen.to(directory, ignore: IGNORE) { |modified, added, _removed| handle(modified + added) }
    end

    def worker(root)
      workers[root] ||= begin
        worker = ProjectWorker.new(root:, name: name(root), bare: @bare, execute: @execute)
        fork? ? ForkedWorker.new(worker).tap(&:start) : worker.tap(&:start)
      end
    end

    # Without fork the projects share this process, where nodes can't be unloaded.
    def restart(root)
      return warn("[#{name(root)}] Restart raindown to load the node changes") unless fork?

      worker = workers.delete(root) || return
      worker.stop
      puts "[#{worker.name}] Reloading nodes"
      worker(root)
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

  # A project's worker in a forked process, which reads the files to update from a pipe until the pipe closes.
  # The process ends with exit! as it's forked mid-call, so exit would run the watcher's ensure and stop its siblings.
  class ForkedWorker
    def initialize(worker)
      @worker = worker
    end

    def name
      @worker.name
    end

    def start
      @writer&.close
      reader, @writer = IO.pipe
      @pid = fork do
        @writer.close
        trap('INT') { exit!(0) }
        @worker.start
        while (path = reader.gets)
          @worker.update(path.chomp)
        end
        exit!(0)
      end
      reader.close
    end

    # A worker that stopped, such as from a crash, starts again for the next file.
    def update(path, restarted: false)
      start unless alive?
      @writer.puts(path)
      @writer.flush
    rescue Errno::EPIPE
      raise if restarted

      start
      update(path, restarted: true)
    end

    def stop
      @writer&.close
      Process.kill('TERM', @pid) if alive?
      Process.wait(@pid)
    rescue Errno::ECHILD, Errno::ESRCH
      nil
    end

    private

    def alive?
      @pid && Process.waitpid(@pid, Process::WNOHANG).nil?
    rescue Errno::ECHILD
      false
    end
  end
end
