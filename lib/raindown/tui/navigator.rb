# frozen_string_literal: true

require_relative 'file_tree'
require_relative 'commands'
require_relative 'endpoints'
require_relative 'focus'
require_relative 'events'
require_relative 'outline'
require_relative 'pane'
require_relative 'project_menu'
require_relative 'views'
require_relative 'workers'

module Raindown
  module TUI
    # What the terminal UI shows and does, in plain Ruby, with no terminal: a FileTree of the project's Markdown files,
    # beside the open file's Outline, or the Dashboard of its charts. The Screen draws it and sends it events, keys like
    # :down, or a Click, and handle returns what the Screen does next: nil to draw again, :quit to stop, or a Run or Wait.
    class Navigator
      include Commands
      include Views
      include ProjectMenu
      include Focus

      # Keys of the events that move the cursor or the focus, and those that act on what's selected.
      MOVES = { up: -1, down: 1 }.freeze
      PANES = { tab: nil, left: :files, right: :main }.freeze
      ACTIONS = { execute: :execute, edit: :edit, write_back: :write_back, reload: :reload, tick: :refresh }.freeze

      attr_reader :focus, :status

      def initialize(root:, path: nil, workers: Workers.new(root:))
        @workers = workers
        @files = FileTree.new(root:)
        @endpoints = Endpoints.new(workers:)
        @focus = :files
        @panes = { files: Pane.new { [*@files.rows, *@endpoints.rows] }, outline: Pane.new { @outline ? @outline.rows : [] } }
        @status = [:info, 'Tab switches panes, Enter opens and folds, q quits']
        first = Projects.files(root, nested: true).first
        show(path || first) if path || first
        # The dashboard is the first page, unless a file is asked for.
        path ? open_file(path) : open_dashboard
      end

      # An event nothing has, like a mouse button's release, does nothing.
      def handle(event)
        case event
        when nil then nil
        when Click then click(event)
        else route(event)
        end
      end

      # After the editor closes, the file is written back, like a save while it's watched, and read again.
      def ran
        write_back
        @endpoints.load
        view.load
      end

      def root = @files.root
      def path = @outline&.path
      def relative(path) = @files.relative(path)

      # The folder the files are shown from: the chosen project's, or the root's.
      def base = @files.base

      def rows(pane) = @panes[pane].rows
      def cursor(pane) = @panes[pane].cursor
      def visible(pane, height) = @panes[pane].visible(height)

      private

      def route(name)
        return :quit if name == :quit
        return menu_event(name) if menu
        return toggle_menu if name == :projects
        return toggle_dashboard if name == :dashboard
        return view_effect(view.handle(name)) if @focus == view.name && view.handles?(name)

        browser_event(name)
      end

      # A click moves the cursor where it's clicked, and does the click's action there, like a key, unless that would
      # leave the terminal UI, like for the editor, so a stray click only moves the cursor.
      # While the project menu's open, only its projects are clicked.
      def click(click)
        return if menu && click.pane != :menu

        point(click)
        effect = route(click.action)
        effect unless effect.is_a?(Run)
      end

      def point(click)
        case click.pane
        when :menu then @menu = click.index
        else (@panes[click.pane] || view).cursor = click.index
        end
        @focus = click.pane unless click.pane == :menu
      end

      def browser_event(name)
        return move(MOVES[name]) if MOVES.key?(name)
        return switch(PANES[name] == :main ? view.name : PANES[name] || other_pane) if PANES.key?(name)
        return activate(name) if %i[enter toggle].include?(name)

        send(ACTIONS[name]) if ACTIONS.key?(name)
      end

      def show(path)
        path = File.expand_path(path)
        @outline = Outline.new(path, worker: @workers.for(path))
        @panes[:outline].reset
      end

      def selected(pane = @focus)
        @panes[pane].selected
      end

      # Enter opens what's selected, or folds it, and Space only folds.
      # A line of output, or a directive without any, opens in the editor.
      def activate(name)
        row = selected
        return edit if name == :enter && editable?(row)
        return open_row(row) if name == :enter && %i[dashboard file endpoint].include?(row&.kind)

        case row&.kind
        when :folder, :project then @files.toggle(row.target)
        when :heading then @outline.fold(row.target)
        when :directive then @outline.expand(row.target) if row.target.body
        end
        nil
      end

      def open_row(row)
        case row.kind
        when :dashboard then open_dashboard
        when :endpoint then open_endpoint(row.target)
        else open_file(row.target)
        end
      end

      def editable?(row)
        row&.kind == :body || (row&.kind == :directive && !row.target.body)
      end
    end
  end
end
