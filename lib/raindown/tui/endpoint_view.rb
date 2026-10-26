# frozen_string_literal: true

require_relative 'events'
require_relative 'worker'

module Raindown
  module TUI
    # An endpoint opened from the files, beside them: its request, and the response its file has, read by its project's
    # Worker, which scrolls. Handle returns the Navigator's next step: nil, or an Open or Edit of the endpoint's directive.
    class EndpointView
      # The date a response was fetched, on the line after it.
      FETCHED = /raindown:fetched (\S+)/
      FENCE = /\A\s*`{3,}(\S*)/

      attr_reader :endpoint, :response, :language, :fetched, :error

      def initialize(endpoint, worker:)
        @endpoint = endpoint
        @worker = worker
        @offset = 0
        read
      end

      # Reads the response again, like after the request's run.
      def read
        lines = output_lines
        @fetched = lines.pop[FETCHED, 1] if lines.last&.match?(FETCHED)
        @language = lines.first.to_s[FENCE, 1]
        @response = @language ? lines[1...-1] : lines
        @error = nil
      rescue Worker::Error => e
        @response = []
        @error = e.message
      end

      def handle(name)
        case name
        when :up, :down then scroll(name == :up ? -1 : 1)
        when :enter then Open.new(path: endpoint.path, line: endpoint.line)
        when :edit then Edit.new(path: endpoint.path, line: endpoint.line)
        end
      end

      # The response's lines that fit in the height, from where it's scrolled to.
      def visible(height)
        @offset = @offset.clamp(0, [response.length - height, 0].max)
        response[@offset, height] || []
      end

      private

      def output_lines
        outline = @worker.call(:outline, endpoint.path)
        directive = outline.directives.find { it.endpoint? && it.line == endpoint.line }
        directive&.output ? outline.lines[(directive.output.begin - 1)...directive.output.end] : []
      end

      def scroll(by)
        @offset += by
        nil
      end
    end
  end
end
