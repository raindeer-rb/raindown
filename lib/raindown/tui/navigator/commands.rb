# frozen_string_literal: true

require_relative '../../actions'

module Raindown
  module TUI
    # What a Navigator does to the open file: run an endpoint, open the editor, write back and read it again,
    # and to a feeling about some code: draw the page it was noted down in, or ask Claude Code to fix the code.
    # Each sets the status, so the Screen shows how it went, and returns what the Screen should do next, if anything.
    module Commands
      def run(file, line, name) = Wait.new(message: "Running #{name}...", task: -> { run_endpoint(file, line) })

      # Opens the editor at the file's line, and writes the file back after it closes.
      def edit_at(file, line)
        @edited = file
        Run.new(command: Actions.edit_command(file, line:))
      end

      def felt(feeling) = info("Felt #{feeling.temper} about #{feeling.method.label}")

      # Leaves the screen for Claude Code, asked to fix the method, and the view reads the code again after.
      def fix_with_agent(feeling)
        return error('Install Claude Code, the claude command, to fix code with X') unless claude?

        @edited = feeling.method.path
        Run.new(command: ['claude', feeling.prompt])
      end

      private

      def claude? = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? { File.executable?(File.join(it, 'claude')) }

      # Runs the endpoint selected in the outline, or listed below the files. One opened beside them runs itself.
      def execute
        target = selected&.target
        return run(target.path, target.line, target.text) if target.is_a?(Endpoint)
        return error('Select an endpoint to run') unless target.is_a?(Document::Directive) && target.endpoint?

        run(path, target.line, "the endpoint on line #{target.line}")
      end

      def run_endpoint(file, line)
        changed = @workers.for(file).call(:execute, file, line)
        view.load
        info(changed ? "Ran the endpoint on line #{line}" : 'The response is the same')
      rescue StandardError => e
        error(e.message)
      end

      # In the nav pane, the selected file opens at its top, and in the outline, the open file at the selected line.
      def edit
        row = selected
        return error('Select a file to edit') if @focus == :nav && row&.kind != :file

        return edit_at(row.target, 1) if @focus == :nav
        return error('Open a file to edit') unless path

        edit_at(path, row ? row.line : 1)
      end

      def write_back(file = path)
        return error('Open a file to write back') unless file

        changed = @workers.for(file).call(:write_back, file)
        view.load
        info(changed ? "Updated #{relative(file)}" : "#{relative(file)} is up to date")
      rescue StandardError => e
        error(e.message)
      end

      # The workers start again too, loading their projects' nodes again, like when one of them has changed.
      def reload
        @workers.restart
        @files.load
        @endpoints.load
        view.load
        info('Reloaded')
      end

      # Reads the file again when it's changed, like when it's saved in an editor or a watcher writes back to it.
      def refresh
        view.load if view.changed?
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
