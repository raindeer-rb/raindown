# frozen_string_literal: true

require_relative 'bare_directives'
require_relative 'curl'

module Raindown
  # Runs the curl block under an endpoint directive and writes the response in the code block below it.
  # Only runs when that block is missing or empty, and the directive has :x/:execute or --execute is passed.
  class EndpointRunner
    DIRECTIVE = /\A {0,3}<\{\s*endpoint:(.*?)\}>[ \t]*$/
    EXECUTE_ARGS = %w[:x :execute].freeze
    FENCE = /\A {0,3}(`{3,}|~{3,})/

    def self.format(content:, path: nil, bare: false, execute: false)
      new(content:, bare: BareDirectives.enabled?(content:, path:, bare:), execute:).format
    end

    def initialize(content:, bare: false, execute: false)
      @lines = content.lines
      @bare = bare
      @execute = execute
    end

    def format
      index = 0

      while index < @lines.length
        if (block = code_block(index))
          index = block[:close]
        elsif (args = directive_args(@lines[index]))
          index = fill(index + 1, args)
        end

        index += 1
      end

      @lines.join
    end

    private

    def directive_args(line)
      line = BareDirectives.expand(line) if @bare
      line[DIRECTIVE, 1]&.split
    end

    # Returns the index of the last line it handled.
    def fill(index, args)
      curl = code_block(skip_blank_lines(index))
      return index - 1 unless curl && curl[:body].lstrip.start_with?('curl')

      output = code_block(skip_blank_lines(curl[:close] + 1))
      return curl[:close] if (output && !output[:body].strip.empty?) || !execute?(args)

      write_output(curl:, output:)
    end

    def execute?(args)
      @execute || args.intersect?(EXECUTE_ARGS)
    end

    # Replaces the output block, or with no block, replaces nothing just after the curl block.
    def write_output(curl:, output:)
      block = output_block(*Curl.run(curl[:body]))
      block.unshift("\n") unless output
      start = output ? output[:open] : curl[:close] + 1

      @lines[start, output ? output[:close] - start + 1 : 0] = block
      start + block.length - 1
    rescue Curl::Error => e
      warn "Endpoint failed: #{e.message}"
      curl[:close]
    end

    # The fence is longer than any run of backticks in the body, so the body can't close it.
    def output_block(body, language)
      fence = '`' * [3, (body.scan(/`+/).map(&:length).max || 0) + 1].max

      ["#{fence}#{language}\n", *"#{body.chomp}\n".lines, "#{fence}\n"]
    end

    def skip_blank_lines(index)
      index += 1 while @lines[index]&.strip&.empty?
      index
    end

    # A fenced code block opening at index, closed by a fence of the same character that's at least as long.
    def code_block(index)
      fence = @lines[index]&.[](FENCE, 1)
      return unless fence

      close = (index + 1...@lines.length).find { |i| @lines[i].match?(/\A {0,3}#{fence[0]}{#{fence.length},}[ \t]*$/) }
      { open: index, close:, body: @lines[index + 1...close].join } if close
    end
  end
end
