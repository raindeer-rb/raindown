# frozen_string_literal: true

require 'shellwords'

require_relative '../raindown'
require_relative 'bare_directives'
require_relative 'endpoint/endpoint_runner'
require_relative 'rewriter'

module Raindown
  # What a tool can do to a file from its Document, like the terminal UI, without knowing how it's drawn.
  # Each returns true when the file changed, and raises when it can't, for the tool to show.
  module Actions
    class NotAnEndpoint < StandardError; end

    # Editors that open a file at a line with "path:line" rather than "+line path".
    PATH_LINE_EDITORS = %w[hx helix subl zed].freeze
    # Editors that need -g before "path:line", and --wait so the tool waits for the file to close.
    GOTO_EDITORS = %w[code codium cursor windsurf].freeze

    module_function

    # Writes back the whole file, like saving it while it's watched.
    def write_back(path)
      Rewriter.update(path:, metadata: Pages.for(path))
    end

    # Runs one endpoint's request and writes its response, replacing any response it had.
    def execute(path, directive)
      raise NotAnEndpoint, "#{directive.name} on line #{directive.line} isn't an endpoint" unless directive.endpoint?

      content = File.read(path, encoding: Encoding::UTF_8)
      rewritten = EndpointRunner.new(content:, bare: BareDirectives.enabled?(path:, content:), only: directive.line - 1).rewrite
      return false if rewritten == content

      File.write(path, rewritten)
      true
    end

    # The command that opens the file at a line in the person's editor, like ["vim", "+12", "notes.md"].
    def edit_command(path, line:, editor: ENV['VISUAL'] || ENV['EDITOR'] || 'vi')
      command = Shellwords.split(editor)
      name = File.basename(command.first)

      if GOTO_EDITORS.include?(name)
        [*command, *('--wait' unless command.include?('--wait')), '-g', "#{path}:#{line}"]
      elsif PATH_LINE_EDITORS.include?(name)
        [*command, "#{path}:#{line}"]
      else
        [*command, "+#{line}", path]
      end
    end
  end
end
