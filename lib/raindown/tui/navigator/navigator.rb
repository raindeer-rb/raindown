# frozen_string_literal: true

require_relative '../file_tree'
require_relative 'commands'
require_relative '../endpoints'
require_relative 'focus'
require_relative '../events'
require_relative '../views/outline_view'
require_relative '../views/list_view'
require_relative 'project_menu'
require_relative 'views'
require_relative '../workers/workers'

module Raindown
  module TUI
    # What the terminal UI shows and does, in plain Ruby, with no terminal: a FileTree of the project's Markdown files,
    # beside the open file's Outline, or the Dashboard of its charts. The Screen draws it and sends it events, keys like
    # :down, or a Click, and next_step returns what the Screen does next: nil to draw again, :quit to stop, or a Run or Wait.
    class Navigator
      include Commands
      include Views
      include ProjectMenu
      include Focus

      # Keys of the events that move the cursor or the focus, and those that act on what's selected.
      MOVES = { up: -1, down: 1 }.freeze
      PANES = { tab: nil, left: :nav, right: :main }.freeze
      ACTIONS = { execute: :execute, edit: :edit, write_back: :write_back, reload: :reload, tick: :refresh }.freeze

      attr_reader :focus, :status

      def initialize(root:, path: nil, workers: Workers.new(root:))
        @workers = workers
        @files = FileTree.new(root:, workers:)
        @endpoints = Endpoints.new(workers:)
        @dashboard = DashboardView.new(root:, workers:)
        @nav = ListView.new { nav_rows }
        first = Projects.files(root, nested: true).first
        # The dashboard is the first page, unless a file is asked for, and "d" goes from it to the first file.
        @view = OutlineView.new(first, workers:) if first
        path ? open_at(path, nil) : open_view(dashboard)
      end

      # An event nothing has, like a mouse button's release, does nothing.
      def next_step(event)
        case event
        when nil then nil
        when Click then click(event)
        else route(event)
        end
      end

      # After the editor closes, the file is written back, like a save while it's watched, and read again.
      def ran
        write_back(@edited)
        @endpoints.load
      end

      def root = @files.root
      def relative(path) = @files.relative(path)

      # The folder the files are shown from: the chosen project's, or the root's.
      def base = @files.base

      # What's in a pane: the nav's ListView on the left, or the view on the right, which keeps its own cursor.
      def content(pane) = pane == :nav ? @nav : view

      private

      def route(name)
        return :quit if name == :quit
        return menu_event(name) if menu
        return toggle_menu if name == :projects
        return toggle_dashboard if name == :dashboard
        return view.next_step(name)&.take(self) if @focus == :main && view.next_step?(name)

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
        return @menu = click.index if click.pane == :menu

        content(click.pane).cursor = click.index
        @focus = click.pane
      end

      def browser_event(name)
        return move(MOVES[name]) if MOVES.key?(name)
        return switch(PANES[name] || other_pane) if PANES.key?(name)
        return activate(name) if %i[enter toggle].include?(name)

        send(ACTIONS[name]) if ACTIONS.key?(name)
      end

      # The Dashboard, which every terminal draws two columns wide, then the files and the endpoints,
      # with a blank line between each section that has rows.
      def nav_rows
        dashboard_row = Row.new(text: '📊 Dashboard', depth: 0, kind: :dashboard, target: dashboard, open: OpenView.new(view: dashboard))
        [[dashboard_row], @files.rows, @endpoints.rows].reject(&:empty?).flat_map { [Row::SEPARATOR, *it] }.drop(1)
      end

      def selected
        content(@focus).selected
      end

      # Enter opens what's selected, or folds it, and Space only folds.
      def activate(name)
        row = selected
        return row.open.take(self) if name == :enter && row&.open

        row&.fold&.call
        nil
      end
    end
  end
end
