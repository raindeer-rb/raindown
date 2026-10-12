# frozen_string_literal: true

require 'json'
require 'open3'
require 'shellwords'

module Raindown
  # Runs a curl snippet with the curl binary. There's no shell, so pipes, redirects and variables don't apply.
  module Curl
    class Error < StandardError; end

    OPERATORS = %w[| || & && ; > >> < 2> 2>&1].freeze
    TIMEOUT = '30'
    # Separates the response body from the content type that --write-out appends.
    TYPE_MARKER = "\n--raindown-content-type--"
    WRITE_OUT = "#{TYPE_MARKER}%{content_type}".freeze # rubocop:disable Style/FormatStringToken -- curl's syntax, not Ruby's
    LANGUAGES = {
      /json/ => 'json', /xml/ => 'xml', /html/ => 'html', /javascript/ => 'javascript',
      /css/ => 'css', /yaml/ => 'yaml', %r{\Atext/plain} => 'text'
    }.freeze

    module_function

    # Returns the response body and the code block language for its content type.
    def run(snippet)
      stdout, stderr, status = Open3.capture3('curl', '--silent', '--show-error', '--max-time', TIMEOUT, *arguments(snippet),
                                              '--write-out', WRITE_OUT)
      raise Error, stderr.strip.empty? ? "curl exited with #{status.exitstatus}" : stderr.strip unless status.success?

      body, _, content_type = stdout.rpartition(TYPE_MARKER)
      language = language(content_type)

      [language == 'json' ? pretty_json(body) : body, language]
    rescue Errno::ENOENT
      raise Error, 'curl is not installed'
    end

    def arguments(snippet)
      words = Shellwords.split(snippet.gsub(/\\\r?\n/, ' ').strip.delete_prefix('$ '))
      raise Error, 'Endpoint snippets must start with curl' unless words.first == 'curl'
      raise Error, 'Endpoint snippets must be a single curl command' if words.intersect?(OPERATORS)

      words.drop(1)
    rescue ArgumentError => e
      raise Error, "Can't read the curl snippet: #{e.message}"
    end

    def language(content_type)
      LANGUAGES.find { |pattern, _| content_type.match?(pattern) }&.last || ''
    end

    def pretty_json(body)
      JSON.pretty_generate(JSON.parse(body))
    rescue JSON::ParserError
      body
    end
  end
end
