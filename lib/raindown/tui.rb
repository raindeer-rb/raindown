# frozen_string_literal: true

require_relative 'projects'
require_relative 'tui/navigator/navigator'

module Raindown
  # The terminal UI, started with "raindown": a project's Markdown files beside the open file's outline,
  # where directives fold, endpoints run and the editor opens at a line. Curses only loads here,
  # so watching and rendering start without it.
  module TUI
    module_function

    # PATH is a file to open, or a directory. Its project is the one it's in, or else the directory itself. It returns
    # true once it's quit. Without a terminal, like in a script or a service, it says so, once curses has loaded, and returns false, to be
    # watched instead, as curses' own error would be "Error opening terminal: unknown". Bare and execute, like --bare and
    # -x, allow bare directives in any file and run endpoints with no response as it writes back.
    def start(path, bare: false, execute: false)
      require_relative 'tui/terminal/screen'
      unless $stdin.tty? && $stdout.tty?
        warn("raindown needs a terminal, so it's watching instead")
        return false
      end

      path = File.expand_path(path)
      root = Projects.root(path) || (File.directory?(path) ? path : File.dirname(path))
      # The projects inside it are shown too. Each loads its own nodes in its worker's process, like when watching,
      # so two projects' nodes of the same name stay apart.
      workers = Project.workers(root:, bare:, execute:)

      # Rouge loads here, rather than with Raindown, which doesn't highlight code outside the TUI.
      require 'rouge'
      # Saved files are written back, like when the folder's watched.
      require_relative 'tui/saves'
      saves = Saves.new(root)
      Screen.new(Navigator.new(root:, path: (path unless File.directory?(path)), workers:, saves:, runs_endpoints: execute)).run
      true
    ensure
      saves&.stop
      workers&.stop
    end
  end
end
