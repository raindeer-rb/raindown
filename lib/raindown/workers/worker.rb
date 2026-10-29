# frozen_string_literal: true

module Raindown
  class Workers
    # What answers a project's requests, made by the block, like the terminal UI's Project, or a Watcher::Project when
    # watching, in a process of its own, forked so it loads the project's nodes apart from other projects'.
    # Requests and answers go through two pipes, as Marshal data, one at a time. Without fork, like on Windows,
    # or with fork off, like in specs, it answers in this process instead. A quiet worker writes nothing, as the terminal
    # UI's screen is its own. The process ends with exit!, since it's forked mid-call, so the parent's ensure doesn't run.
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

      def initialize(root:, fork: self.class.fork?, quiet: true, &answering)
        @root = root
        @fork = fork
        @quiet = quiet
        @answering = answering
      end

      # The answer, or a Worker::Error with its error's message. A worker that stopped starts again.
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

      # Starts the worker's process, or makes what answers in this one, so it's ready before the first request.
      def start
        return @answerer ||= @answering.call unless @fork

        stop
        requests, answers = open_pipes
        @pid = fork do
          self.class.pipes.each { it.close unless it.closed? }
          serve(requests, answers)
        end
        requests.close
        answers.close
      end

      private

      # The worker's ends of the pipes, while this process keeps the others.
      def open_pipes
        requests, @requests = IO.pipe
        @answers, answers = IO.pipe
        self.class.pipes.reject!(&:closed?)
        self.class.pipes.push(@requests, @answers)
        [requests, answers]
      end

      def local(name, args, options)
        start.public_send(name, *args, **options)
      rescue StandardError => e
        raise Error, e.message
      end

      # Answers until the parent closes its end. Ctrl+C, which reaches every process in the terminal, is the parent's to
      # handle, stopping its workers.
      def serve(requests, answers)
        trap('INT', 'IGNORE')
        [$stdout, $stderr].each { it.reopen(File::NULL) } if @quiet
        answerer = @answering.call

        while (request = read(requests))
          write(answers, answer(answerer, *request))
        end
      ensure
        exit!(0)
      end

      def answer(answerer, name, args, options)
        [:ok, answerer.public_send(name, *args, **options)]
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
