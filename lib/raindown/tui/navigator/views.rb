# frozen_string_literal: true

require_relative '../views/dashboard_view'
require_relative '../views/endpoint_view'
require_relative '../views/outline_view'

module Raindown
  module TUI
    # Beside the files, a Navigator shows a view: the open file's Outline, the Dashboard of the project's charts,
    # which is the first item in the files and "d" switches to, or an EndpointView of an endpoint listed below them.
    # A view has the pane that draws it, a next step for the keys it takes while it has the focus, and a target,
    # what's opened it in the files. It loads when it's opened, and again after a change.
    module Views
      attr_reader :view, :dashboard

      # The path of the file the view shows, if any.
      def path = view.path

      # Shows the view right of the files, with the focus, and the files' cursor on the row that opened it.
      def open_view(view)
        @previous = @view unless view == @view
        @view = view
        @focus = :main
        @nav.cursor = @nav.rows.index { it.target == view.target } || 0
        view.load
        @status = view.status(self)
        nil
      end

      # Opens the file in the outline, on the directive at the line.
      def open_at(path, line)
        path = File.expand_path(path)
        @files.reveal(path)
        open_view(OutlineView.new(path, workers: @workers))
        view.cursor = view.rows.index { it.kind == :directive && it.target.line == line } || 0
        nil
      end

      private

      # Switches between the dashboard and the view before it.
      def toggle_dashboard
        return open_view(@previous) if view == dashboard && @previous

        open_view(dashboard)
      end
    end
  end
end
