# frozen_string_literal: true

require_relative 'dashboard'

module Raindown
  module TUI
    # Beside the files, a Navigator shows the open file's outline, or the dashboard of the project's charts,
    # which is the first item in the files and "d" switches to. The dashboard finds its charts each time it's shown,
    # and opens a chart's file in the outline at its directive.
    module Views
      def view = @view || :browser

      def dashboard
        @dashboard ||= Dashboard.new(root:, workers: @workers)
      end

      # The pane right of the files, which the cursor moves to with Tab.
      def main_pane = view == :dashboard ? :dashboard : :outline

      private

      # Events for the dashboard: its cards' clicks, and keys while it has the focus, other than Tab to the files,
      # or left from the first card in a row.
      def dashboard_event?(event)
        name, pane = event
        return pane == :dashboard if %i[select press].include?(name)
        return false if name == :left && dashboard.first_in_row?

        @focus == :dashboard && !%i[tab tick].include?(name)
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

      def dashboard_effect(effect)
        name, path, line = effect
        case name
        when :open then open_at(path, line)
        when :edit
          show(path)
          [:run, Actions.edit_command(path, line:)]
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
