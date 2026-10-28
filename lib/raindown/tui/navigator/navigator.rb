# frozen_string_literal: true

require_relative '../file_tree'
require_relative 'commands'
require_relative '../endpoints'
require_relative 'focus'
require_relative '../events'
require_relative '../views/outline_view'
require_relative '../views/list_view'
require_relative 'project_menu'
require_relative 'search'
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
      include Search
      include Focus

      # Keys of the events that move the cursor or the focus, and those that act on what's selected.
      MOVES = { up: -1, down: 1 }.freeze
      PANES = { tab: nil, left: :nav, right: :main }.freeze
      ACTIONS = { execute: :execute, edit: :edit, write_back: :write_back, reload: :reload, tick: :refresh }.freeze
      # Keys that open the search, the project menu, the Dashboard or Code feelings, from anywhere.
      OPENERS = { search: :open_search, projects: :toggle_menu, dashboard: :toggle_dashboard, feelings: :open_feelings }.freeze

      attr_reader :focus, :status
      # What the mouse is over, which a click there would send, like a Click on a method's cells, or nil.
      attr_reader :hovered

      def initialize(root:, path: nil, workers: Workers.new(root:))
        @workers = workers
        @files = FileTree.new(root:, workers:)
        @endpoints = Endpoints.new(workers:)
        @dashboard = DashboardView.new(root:, workers:)
        @feelings = FeelingsView.new(root:)
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
        when Type then type(event)
        when Hover then hover(event)
        else route(event)
        end
      end

      # After the editor closes, a Markdown file is written back, like a save while it's watched, and read again.
      # Other files, like code that was felt, aren't written back, and the view reads them again.
      def ran
        write_back(@edited) if @files.files.include?(@edited)
        view.load
        @endpoints.load
      end

      def root = @files.root
      def relative(path) = @files.relative(path)

      # The folder the files are shown from: the chosen project's, or the root's.
      def base = @files.base

      # While the search, or the view, like a feeling's note, takes what's typed, rather than keys' events.
      def typing? = searching? || view.typing?

      # While the view wants drawing faster than the ticks, like Code feelings' rain.
      def animating? = view.animating?

      # What's in a pane: the nav's ListView on the left, or the view on the right, which keeps its own cursor.
      def content(pane) = pane == :nav ? @nav : view

      private

      def hover(hover)
        @hovered = hover.target
        nil
      end

      # A typed character goes to the search, or to the view while it's typing.
      def type(event)
        return type_query(query + event.text) if searching?

        view.next_step(event)&.take(self) if view.typing?
      end

      def route(name)
        return :quit if name == :quit
        return search_event(name) if searching?
        return menu_event(name) if menu
        return send(OPENERS[name]) if OPENERS.key?(name)
        return view.next_step(name)&.take(self) if @focus == :main && view.next_step?(name)

        browser_event(name)
      end

      # A click moves the cursor where it's clicked, and does the click's action there, like a key, unless that would
      # leave the terminal UI, like for the editor, so a stray click only moves the cursor.
      # While the project menu or the search is open, only its items are clicked.
      def click(click)
        return if menu && click.pane != :menu
        return if searching? && click.pane != :search

        point(click)
        effect = route(click.action)
        effect unless effect.is_a?(Run)
      end

      def point(click)
        return @menu = click.index if click.pane == :menu
        return @match = click.index if click.pane == :search

        content(click.pane).cursor = click.index
        @focus = click.pane
      end

      def browser_event(name)
        return move(MOVES[name]) if MOVES.key?(name)
        return switch(PANES[name] || other_pane) if PANES.key?(name)
        return activate(name) if %i[enter toggle].include?(name)

        send(ACTIONS[name]) if ACTIONS.key?(name)
      end

      # The Dashboard and Code feelings, whose emoji every terminal draws two columns wide, then the files and the
      # endpoints, with a blank line between each section that has rows.
      def nav_rows
        pages = { '📊 Dashboard' => dashboard, '🎭 Feelings' => feelings }.map do |text, view|
          Row.new(text:, depth: 0, kind: :page, target: view, open: OpenView.new(view:))
        end
        [pages, @files.rows, @endpoints.rows].reject(&:empty?).flat_map { [Row::SEPARATOR, *it] }.drop(1)
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
