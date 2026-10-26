# frozen_string_literal: true

require_relative 'file_tree'
require_relative 'commands'
require_relative 'outline'
require_relative 'pane'
require_relative 'views'

module Raindown
  module TUI
    # What the terminal UI shows and does, in plain Ruby, with no terminal: a FileTree of the project's Markdown files,
    # beside the open file's Outline, or the Dashboard of its charts. The Screen draws it and sends it events, like :down or
    # [:press, :outline, 3, :execute], and handle returns what the Screen should do next:
    #   nil                     draw again
    #   :quit                   stop
    #   [:run, command]         leave the screen to run a command, like the editor, then call ran
    #   [:wait, message, task]  show the message while the task runs, like an endpoint's request
    class Navigator
      include Commands
      include Views

      # Keys of the events that move the cursor or the focus, and those that act on what's selected.
      MOVES = { up: -1, down: 1 }.freeze
      PANES = { tab: nil, left: :files, right: :main }.freeze
      ACTIONS = { execute: :execute, edit: :edit, write_back: :write_back, reload: :reload, tick: :refresh }.freeze

      attr_reader :focus, :status

      def initialize(root:, path: nil)
        @files = FileTree.new(root:)
        @focus = :files
        @panes = { files: Pane.new { @files.rows }, outline: Pane.new { @outline ? @outline.rows : [] } }
        @status = [:info, 'Tab switches panes, Enter opens and folds, q quits']
        first = Projects.files(root, nested: true).first
        show(path || first) if path || first
        # The dashboard is the first page, unless a file is asked for.
        path ? open_file(path) : open_dashboard
      end

      def handle(event)
        name, = event
        return :quit if name == :quit
        return toggle_dashboard if name == :dashboard
        return dashboard_effect(dashboard.handle(event)) if dashboard_event?(event)

        browser_event(event)
      end

      # After the editor closes, the file is written back, like a save while it's watched, and read again.
      def ran
        write_back
        dashboard.load if view == :dashboard
      end

      def root = @files.root
      def path = @outline&.path
      def relative(path) = @files.relative(path)

      def rows(pane) = @panes[pane].rows
      def cursor(pane) = @panes[pane].cursor
      def visible(pane, height) = @panes[pane].visible(height)

      private

      def browser_event(event)
        name, *args = event
        return move(MOVES[name]) if MOVES.key?(name)
        return switch(PANES[name] == :main ? main_pane : PANES[name] || other_pane) if PANES.key?(name)
        return select(*args) if name == :select
        return press(*args) if name == :press
        return activate(name) if %i[enter toggle].include?(name)

        send(ACTIONS[name]) if ACTIONS.key?(name)
      end

      def show(path)
        @outline = Outline.new(File.expand_path(path))
        @panes[:outline].reset
      end

      def other_pane
        @focus == :files ? main_pane : :files
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
        return open_row(row) if name == :enter && %i[dashboard file].include?(row&.kind)

        case row&.kind
        when :folder then @files.toggle(row.target)
        when :heading then @outline.fold(row.target)
        when :directive then @outline.expand(row.target) if row.target.body
        end
        nil
      end

      def open_row(row)
        row.kind == :dashboard ? open_dashboard : open_file(row.target)
      end

      def editable?(row)
        row&.kind == :body || (row&.kind == :directive && !row.target.body)
      end

      def open_file(path)
        path = File.expand_path(path)
        show(path)
        @files.reveal(path)
        @view = :browser
        @focus = :outline
        @panes[:files].cursor = rows(:files).index { it.target == path } || 0
        info("Opened #{relative(path)}")
      end
    end
  end
end
