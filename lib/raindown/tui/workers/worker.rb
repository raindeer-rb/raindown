# frozen_string_literal: true

require_relative 'project'

module Raindown
  module TUI
    # A Project in a process of its own, forked so it loads the project's nodes apart from other projects', like watching.
    # Requests and answers go through two pipes, as Marshal data, one at a time. Without fork, like on Windows,
    # or with fork off, like in specs, the Project answers in this process instead.
    # The process ends with exit!, since it's forked mid-call, so the terminal UI's ensure doesn't run in it.
    class Worker
      class Error < StandardError; end

      class << self
        attr_writer :fork

        def fork?
          @fork.nil? ? Process.respond_to?(:fork) : @fork
        end

        # Every worker's pipes, which a new worker closes the others of, since a worker holding another's pipe open
        # would keep that worker from seeing it close.
        def pipes
          @pipes ||= []
        end
      end

      attr_reader :root

      def initialize(root:, fork: self.class.fork?)
        @root = root
        @fork = fork
      end

      # The Project's answer, or a Worker::Error with its error's message. A worker that stopped starts again.
      def call(name, *args, **options)
        return local(name, args, options) unless @fork

        start unless alive?
        write(@requests, [name, args, options])
        status, value = read(@answers) || raise(Error, "The worker for #{File.basename(root)} stopped")
        status == :ok ? value : raise(Error, value)
      end

      def stop
        [@requests, @answers].compact.each { it.close unless it.closed? }
        return unless @pid

        Process.kill('TERM', @pid)
        Process.wait(@pid)
      rescue Errno::ECHILD, Errno::ESRCH
        nil
      ensure
        @pid = nil
      end

      private

      def local(name, args, options)
        @project ||= Project.new(root:)
        @project.public_send(name, *args, **options)
      rescue StandardError => e
        raise Error, e.message
      end

      def start
        stop
        requests, @requests = IO.pipe
        @answers, answers = IO.pipe
        self.class.pipes.reject!(&:closed?)
        self.class.pipes.push(@requests, @answers)
        @pid = fork do
          self.class.pipes.each { it.close unless it.closed? }
          serve(requests, answers)
        end
        requests.close
        answers.close
      end

      # Answers until the terminal UI closes its end. The screen is the terminal UI's, so nothing is written to it,
      # and Ctrl+C, which reaches every process in the terminal, is the terminal UI's to handle.
      def serve(requests, answers)
        trap('INT', 'IGNORE')
        $stdout.reopen(File::NULL)
        $stderr.reopen(File::NULL)
        project = Project.new(root:)

        while (request = read(requests))
          write(answers, answer(project, *request))
        end
      ensure
        exit!(0)
      end

      def answer(project, name, args, options)
        [:ok, project.public_send(name, *args, **options)]
      rescue StandardError, ScriptError => e
        [:error, e.message]
      end

      def alive?
        @pid && Process.waitpid(@pid, Process::WNOHANG).nil?
      rescue Errno::ECHILD
        false
      end

      # A message is its length, then its Marshal data.
      def write(io, message)
        data = Marshal.dump(message)
        io.write([data.bytesize].pack('N'), data)
        io.flush
      rescue Errno::EPIPE, IOError
        raise Error, "The worker for #{File.basename(root)} stopped"
      end

      def read(io)
        length = io.read(4)&.unpack1('N')
        Marshal.load(io.read(length)) if length # rubocop:disable Security/MarshalLoad -- from this process's own fork
      rescue IOError
        nil
      end
    end
  end
end
