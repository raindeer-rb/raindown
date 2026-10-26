# frozen_string_literal: true

require_relative 'file_tree'
require_relative 'commands'
require_relative 'outline'
require_relative 'pane'

module Raindown
  module TUI
    # What the terminal UI shows and does, in plain Ruby, with no terminal: a FileTree of the project's Markdown files,
    # beside the open file's Outline. The Screen draws it and sends it events, like :down or
    # [:press, :outline, 3, :execute], and handle returns what the Screen should do next:
    #   nil                     draw again
    #   :quit                   stop
    #   [:run, command]         leave the screen to run a command, like the editor, then call ran
    #   [:wait, message, task]  show the message while the task runs, like an endpoint's request
    class Navigator
      include Commands

      # Keys of the events that move the cursor or the focus, and those that act on what's selected.
      MOVES = { up: -1, down: 1 }.freeze
      PANES = { tab: nil, left: :files, right: :outline }.freeze
      ACTIONS = { execute: :execute, edit: :edit, write_back: :write_back, reload: :reload, tick: :refresh }.freeze

      attr_reader :focus, :status

      def initialize(root:, path: nil)
        @files = FileTree.new(root:)
        @focus = :files
        @panes = { files: Pane.new { @files.rows }, outline: Pane.new { @outline ? @outline.rows : [] } }
        @status = [:info, 'Tab switches panes, Enter opens and folds, q quits']
        first = @files.rows.find { it.kind == :file }&.target
        show(path || first) if path || first
      end

      def handle(event)
        name, *args = event
        return :quit if name == :quit
        return move(MOVES[name]) if MOVES.key?(name)
        return switch(PANES[name] || other_pane) if PANES.key?(name)
        return select(*args) if name == :select
        return press(*args) if name == :press
        return activate(name) if %i[enter toggle].include?(name)

        send(ACTIONS[name]) if ACTIONS.key?(name)
      end

      # After the editor closes, the file is written back, like a save while it's watched, and read again.
      def ran
        write_back
      end

      def root = @files.root
      def path = @outline&.path
      def relative(path) = @files.relative(path)

      def rows(pane) = @panes[pane].rows
      def cursor(pane) = @panes[pane].cursor
      def visible(pane, height) = @panes[pane].visible(height)

      private

      def show(path)
        @outline = Outline.new(File.expand_path(path))
        @panes[:outline].reset
      end

      def other_pane
        @focus == :files ? :outline : :files
      end

      def move(by)
        @panes[@focus].move(by)
        nil
      end

      def switch(pane)
        @focus = pane
        nil
      end

      def select(pane, index)
        @focus = pane
        @panes[pane].cursor = index
        nil
      end

      def press(pane, index, event)
        select(pane, index)
        handle(event)
      end

      def selected(pane = @focus)
        @panes[pane].selected
      end

      # Enter opens what's selected, or folds it, and Space only folds.
      # A line of output, or a directive without any, opens in the editor.
      def activate(name)
        row = selected
        return edit if name == :enter && editable?(row)

        case row&.kind
        when :folder then @files.toggle(row.target)
        when :file then open_file(row.target) if name == :enter
        when :heading then @outline.fold(row.target)
        when :directive then @outline.expand(row.target) if row.target.output
        end
        nil
      end

      def editable?(row)
        row&.kind == :output || (row&.kind == :directive && !row.target.output)
      end

      def open_file(path)
        show(path)
        @focus = :outline
        info("Opened #{relative(path)}")
      end
    end
  end
end
