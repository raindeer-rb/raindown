# frozen_string_literal: true

require_relative 'dashboard'
require_relative 'endpoint_view'

module Raindown
  module TUI
    # Beside the files, a Navigator shows the open file's outline, or the dashboard of the project's charts,
    # which is the first item in the files and "d" switches to, or an endpoint opened from the files.
    # The dashboard finds its charts each time it's shown, and opens a chart's file in the outline at its directive,
    # as an endpoint does its own.
    module Views
      def view = @view || :browser

      def dashboard
        @dashboard ||= Dashboard.new(root:, workers: @workers)
      end

      # The endpoint opened from the files, while it's shown.
      attr_reader :endpoint_view

      # The pane right of the files, which the cursor moves to with Tab.
      def main_pane = { dashboard: :dashboard, endpoint: :endpoint }.fetch(view, :outline)

      private

      # Keys for the dashboard, while it has the focus, other than Tab to the files, or left from the first card in a row.
      def dashboard_event?(name)
        return false if name == :left && dashboard.first_in_row?

        @focus == :dashboard && !%i[tab tick].include?(name)
      end

      # Keys for the endpoint, while it has the focus, to scroll its response and open its directive.
      def endpoint_event?(name) = @focus == :endpoint && %i[up down enter edit].include?(name)

      def open_endpoint(endpoint)
        @view = :endpoint
        @endpoint_view = EndpointView.new(endpoint, worker: @workers.for(endpoint.path))
        info(endpoint.text)
      end

      def toggle_dashboard
        return open_file(path) if view == :dashboard && path

        open_dashboard
      end

      # The cursor stays on the Dashboard in the files, and Tab or right moves it to the charts.
      def open_dashboard
        @view = :dashboard
        @focus = :files
        @panes[:files].cursor = 0
        dashboard.load
        count = dashboard.charts.length
        found = "#{count} #{count == 1 ? 'chart' : 'charts'} in #{File.basename(project || root)}"
        dashboard.errors.empty? ? info(found) : error("#{found}, but couldn't read #{dashboard.errors.join(', ')}")
      end

      # What the dashboard or an endpoint asks for, to open or edit a directive.
      def view_effect(effect)
        case effect
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
        @view = :browser
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
