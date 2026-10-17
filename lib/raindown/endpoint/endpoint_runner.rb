# frozen_string_literal: true

require 'date'
require_relative '../bare_directives'
require_relative '../code_blocks'
require_relative 'curl'

module Raindown
  # Runs the curl block under an endpoint directive and writes the response in the code block below it,
  # followed by the date it was fetched.
  # Only runs when that block is missing or empty, and the directive has :x/:execute or --execute is passed.
  #   <{ endpoint: :x }>
  #   ```sh
  #   curl https://api.example.com
  #   ```
  #   ```json
  #   { "id": 1 }
  #   ```
  #   <!-- raindown:fetched 2026-10-14 -->
  #   <{ :endpoint }>
  class EndpointRunner
    DIRECTIVE = /\A {0,3}<\{\s*endpoint:(.*?)\}>[ \t]*$/
    EXECUTE_ARGS = %w[:x :execute].freeze
    # The date a response was fetched, on the line after it.
    FETCHED = /\A {0,3}<!-- raindown:fetched [^\n]*? -->[ \t]*$/

    def self.rewrite(content:, path: nil, bare: false, execute: false, **)
      new(content:, bare: BareDirectives.enabled?(path:, bare:), execute:).rewrite
    end

    def initialize(content:, bare: false, execute: false)
      @lines = content.lines
      @bare = bare
      @execute = execute
    end

    def rewrite
      index = 0

      while index < @lines.length
        if (block = CodeBlocks.at(@lines, index))
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
      line = BareDirectives.wrap(line) || line if @bare
      line[DIRECTIVE, 1]&.split
    end

    # Returns the index of the last line it handled.
    def fill(index, args)
      curl, output = CodeBlocks.endpoint(@lines, index)
      return index - 1 unless curl&.dig(:body)&.lstrip&.start_with?('curl')

      return curl[:close] if (output && !output[:body].strip.empty?) || !execute?(args)

      write_output(curl:, output:)
    end

    def execute?(args)
      @execute || args.intersect?(EXECUTE_ARGS)
    end

    # Replaces the output block and the date it was fetched, or with no block, replaces nothing just after the curl block.
    def write_output(curl:, output:)
      block = [*output_block(*Curl.run(curl[:body])), fetched]
      block.unshift("\n") unless output
      start = output ? output[:open] : curl[:close] + 1

      @lines[start, output ? replaced_length(output) : 0] = block
      start + block.length - 1
    rescue Curl::Error => e
      warn "Endpoint failed: #{e.message}"
      curl[:close]
    end

    # The output block, and the line after it when that's the date it was last fetched.
    def replaced_length(output)
      length = output[:close] - output[:open] + 1
      @lines[output[:close] + 1]&.match?(FETCHED) ? length + 1 : length
    end

    def fetched
      "<!-- raindown:fetched #{Date.today.iso8601} -->\n"
    end

    # The fence is longer than any run of backticks in the body, so the body can't close it.
    def output_block(body, language)
      fence = '`' * [3, (body.scan(/`+/).map(&:length).max || 0) + 1].max

      ["#{fence}#{language}\n", *"#{body.chomp}\n".lines, "#{fence}\n"]
    end
  end
end
