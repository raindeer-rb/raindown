# frozen_string_literal: true

require_relative '../events'
require_relative '../../workers/worker'

module Raindown
  module TUI
    # An endpoint opened from the files, beside them: its request, and the response its file has, read by its project's
    # Worker when it's opened, which scrolls.
    # A key's next step, for the Navigator, is nil, an Open or Edit of its directive, or an Execute of it.
    class EndpointView
      # The date a response was fetched, on the line after it.
      FETCHED = /raindown:fetched (\S+)/
      FENCE = /\A\s*`{3,}(\S*)/

      attr_reader :endpoint, :response, :language, :fetched, :error

      def initialize(endpoint, workers:)
        @endpoint = endpoint
        @workers = workers
        @offset = 0
      end

      def renderer = EndpointRenderer
      def target = endpoint
      def path = endpoint.path
      def status(_navigator) = [:info, endpoint.text]
      def changed? = false
      def typing? = false
      def pace(_hovered) = :active
      def next_step?(key) = %i[up down enter edit execute].include?(key)

      # Clicks on the response only move the focus to it.
      def cursor=(_index); end

      # Reads the response again, like after the request's run.
      def load
        lines = output_lines
        @fetched = lines.pop[FETCHED, 1] if lines.last&.match?(FETCHED)
        @language = lines.first.to_s[FENCE, 1]
        @response = @language ? lines[1...-1] : lines
        @error = nil
      rescue Workers::Worker::Error => e
        @response = []
        @error = e.message
      end

      def next_step(key)
        case key
        when :up, :down then scroll(key == :up ? -1 : 1)
        when :enter then Open.new(path: endpoint.path, line: endpoint.line)
        when :edit then Edit.new(path: endpoint.path, line: endpoint.line)
        when :execute then Execute.new(path: endpoint.path, line: endpoint.line, name: endpoint.text)
        end
      end

      # The response's lines that fit in the height, from where it's scrolled to.
      def visible(height)
        @offset = @offset.clamp(0, [response.length - height, 0].max)
        response[@offset, height] || []
      end

      private

      def output_lines
        outline = @workers.for(path).call(:outline, path)
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
