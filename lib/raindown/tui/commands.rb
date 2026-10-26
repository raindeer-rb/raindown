# frozen_string_literal: true

require_relative '../actions'

module Raindown
  module TUI
    # What a Navigator does to the open file: run an endpoint, open the editor, write back and read it again.
    # Each sets the status, so the Screen shows how it went, and returns what the Screen should do next, if anything.
    module Commands
      private

      def execute
        directive = selected(:outline)&.target if @focus == :outline
        return error('Select an endpoint to run') unless directive.is_a?(Document::Directive) && directive.endpoint?

        Wait.new(message: "Running the endpoint on line #{directive.line}...", task: -> { run_endpoint(directive) })
      end

      def run_endpoint(directive)
        changed = @workers.for(path).call(:execute, path, directive.line)
        @outline.read
        info(changed ? "Ran the endpoint on line #{directive.line}" : 'The response is the same')
      rescue StandardError => e
        error(e.message)
      end

      # In the files pane, the selected file opens at its top, and in the outline, the open file at the selected line.
      def edit
        row = selected
        return error('Select a file to edit') if @focus == :files && row&.kind != :file

        show(row.target) if @focus == :files
        return error('Open a file to edit') unless path

        line = @focus == :outline && row ? row.line : 1
        Run.new(command: Actions.edit_command(path, line:))
      end

      def write_back
        return error('Open a file to write back') unless path

        changed = @workers.for(path).call(:write_back, path)
        @outline.read
        info(changed ? "Updated #{relative(path)}" : "#{relative(path)} is up to date")
      rescue StandardError => e
        error(e.message)
      end

      # The workers start again too, loading their projects' nodes again, like when one of them has changed.
      def reload
        @workers.restart
        @files.load
        @outline&.read if path && File.exist?(path)
        dashboard.load if view == :dashboard
        info('Reloaded')
      end

      # Reads the file again when it's changed, like when it's saved in an editor or a watcher writes back to it.
      def refresh
        @outline.read if @outline&.changed?
        nil
      end

      def info(message)
        @status = [:info, message]
        nil
      end

      def error(message)
        @status = [:error, message]
        nil
      end
    end
  end
end
