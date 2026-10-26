# frozen_string_literal: true

require_relative 'projects'
require_relative 'tui/navigator'

module Raindown
  # The terminal UI, started with "raindown tui": a project's Markdown files beside the open file's outline,
  # where directives fold, endpoints run and the editor opens at a line. Curses only loads here,
  # so watching and rendering start without it.
  module TUI
    module_function

    # PATH is a file to open, or a directory. Its project is the one it's in, or else the directory itself.
    def start(path)
      require_relative 'tui/screen'
      # Without a terminal, curses' own error is "Error opening terminal: unknown".
      abort('raindown tui needs a terminal') unless $stdin.tty? && $stdout.tty?

      path = File.expand_path(path)
      root = Projects.root(path) || (File.directory?(path) ? path : File.dirname(path))
      # The projects inside it are shown too. Each loads its own nodes in its worker's process, like when watching,
      # so two projects' nodes of the same name stay apart.
      workers = Workers.new(root:)

      Screen.new(Navigator.new(root:, path: (path unless File.directory?(path)), workers:)).run
    ensure
      workers&.stop
    end
  end
end
