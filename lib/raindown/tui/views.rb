# frozen_string_literal: true

require_relative 'dashboard'
require_relative 'endpoint_view'

module Raindown
  module TUI
    # Beside the files, a Navigator shows the open file's outline, or the dashboard of the project's charts,
    # which is the first item in the files and "d" switches to, or an endpoint opened from the files.
    # The dashboard finds its charts each time it's shown, and opens a chart's file in the outline at its directive,
    # as an endpoint does its own.
    # A view is named after its pane, handles the keys it has while that has the focus, and loads again after a change.
    module Views
      # The open file's outline, whose keys the Navigator handles itself, as they move between rows like the files'.
      OutlineView = Data.define do
        def name = :outline
        def handles?(_key) = false
        def load = nil
      end

      # An OutlineView, the Dashboard, or an EndpointView, named after the pane right of the files, which Tab moves to.
      attr_reader :view

      def dashboard
        @dashboard ||= Dashboard.new(root:, workers: @workers)
      end

      private

      def open_endpoint(endpoint)
        @view = EndpointView.new(endpoint, worker: @workers.for(endpoint.path))
        info(endpoint.text)
      end

      def toggle_dashboard
        return open_file(path) if view == dashboard && path

        open_dashboard
      end

      # The cursor stays on the Dashboard in the files, and Tab or right moves it to the charts.
      def open_dashboard
        @view = dashboard
        @focus = :files
        @panes[:files].cursor = 0
        @view.load
        count = @view.charts.length
        found = "#{count} #{count == 1 ? 'chart' : 'charts'} in #{File.basename(project || root)}"
        @view.errors.empty? ? info(found) : error("#{found}, but couldn't read #{@view.errors.join(', ')}")
      end

      # What the dashboard or an endpoint asks for, to open or edit a directive, or run an endpoint.
      def view_effect(effect)
        case effect
        when Endpoint then run(effect.path, effect.line, effect.text)
        when Open then open_at(effect.path, effect.line)
        when Edit
          show(effect.path)
          Run.new(command: Actions.edit_command(effect.path, line: effect.line))
        end
      end

      def open_file(path)
        path = File.expand_path(path)
        show(path)
        @files.reveal(path)
        @view = OutlineView.new
        @focus = :outline
        @panes[:files].cursor = rows(:files).index { it.target == path } || 0
        info("Opened #{relative(path)}")
      end

      # Opens the file in the outline, on the directive at the line.
      def open_at(path, line)
        open_file(path)
        @panes[:outline].cursor = rows(:outline).index { it.kind == :directive && it.target.line == line } || 0
        nil
      end
    end
  end
end
