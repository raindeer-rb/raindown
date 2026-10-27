# frozen_string_literal: true

require 'json'
require 'open3'
require 'shellwords'

module Raindown
  # Runs a curl snippet with the curl binary. There's no shell, so pipes, redirects and variables don't apply.
  # Snippets come from files that anyone (or any agent) may have written, so only options that make an HTTP request
  # are allowed: nothing that reads or writes local files, loads a config, or uses another protocol.
  module Curl
    class Error < StandardError; end
    Request = Data.define(:method, :url)

    TIMEOUT = '30'
    # --disable must come first and skips ~/.curlrc. The protocol options stop redirects to file:// and the like.
    SAFE_OPTIONS = ['--disable', '--proto', '=http,https', '--proto-redir', '=http,https'].freeze

    OPERATORS = %w[| || & && ; > >> < 2> 2>&1].freeze
    URL = %r{\Ahttps?://}i

    # Options without a value.
    FLAGS = {
      '-G' => '--get', '-I' => '--head', '-L' => '--location', '-i' => '--include', '-k' => '--insecure',
      '-f' => '--fail', '-g' => '--globoff', '-s' => '--silent', '-S' => '--show-error'
    }.freeze
    LONG_FLAGS = (FLAGS.values + %w[--compressed --http1.1 --http2]).freeze

    # Options with a value, and how the value is checked.
    VALUE_OPTIONS = {
      '-X' => '--request', '-H' => '--header', '-d' => '--data', '-A' => '--user-agent', '-e' => '--referer',
      '-u' => '--user'
    }.freeze
    VALUE_CHECKS = {
      '--request' => :any, '--user-agent' => :any, '--referer' => :any, '--user' => :any, '--data-raw' => :any,
      '--url' => :url,
      # "@file" reads a file.
      '--header' => :no_file, '--data' => :no_file, '--data-ascii' => :no_file, '--data-binary' => :no_file,
      '--json' => :no_file,
      # "@file" and "name@file" read a file, but "name=a@b" doesn't.
      '--data-urlencode' => :no_urlencoded_file
    }.freeze

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
      stdout, stderr, status = Open3.capture3('curl', *SAFE_OPTIONS, '--silent', '--show-error', '--max-time', TIMEOUT,
                                              *arguments(snippet), '--write-out', WRITE_OUT)
      raise Error, stderr.strip.empty? ? "curl exited with #{status.exitstatus}" : stderr.strip unless status.success?

      body, _, content_type = stdout.rpartition(TYPE_MARKER)
      language = language(content_type)

      [language == 'json' ? pretty_json(body) : body, language]
    rescue Errno::ENOENT
      raise Error, 'curl is not installed'
    end

    # The snippet's method and URL, like GET https://httpbin.org/uuid, or nil when it can't be read.
    # A snippet that sends data is a POST, unless it says otherwise, as with curl.
    def request(snippet)
      args = arguments(snippet)
      url = args.find { it.match?(URL) }
      method = args[args.index('--request') + 1] if args.include?('--request')
      method ||= 'HEAD' if args.include?('--head')
      method ||= 'POST' if args.intersect?(VALUE_CHECKS.keys.grep(/data|json/))

      Request.new(method: (method || 'GET').upcase, url:) if url
    rescue Error
      nil
    end

    def arguments(snippet)
      words = Shellwords.split(snippet.gsub(/\\\r?\n/, ' ').strip.delete_prefix('$ '))
      raise Error, 'Endpoint snippets must start with curl' unless words.first == 'curl'
      raise Error, 'Endpoint snippets must be a single curl command' if words.intersect?(OPERATORS)

      check(words.drop(1))
    rescue ArgumentError => e
      raise Error, "Can't read the curl snippet: #{e.message}"
    end

    # Returns the arguments with short options spelled long, or raises on anything not allowed.
    def check(words)
      args = []
      words = words.dup

      until words.empty?
        word = words.shift

        if word.start_with?('--') then args.concat(long_option(word, words))
        elsif word.start_with?('-') && word.length > 1 then args.concat(short_options(word, words))
        else args << url(word)
        end
      end

      raise Error, 'Endpoint snippets need a URL' unless args.any? { |arg| arg.match?(URL) }

      args
    end

    def long_option(option, words)
      return [option] if LONG_FLAGS.include?(option)
      raise Error, "curl's #{option} option isn't allowed in endpoint snippets" unless VALUE_CHECKS.key?(option)
      raise Error, "curl's #{option} option needs a value" if words.empty?

      [option, value(option, words.shift)]
    end

    # Short flags can be grouped like -sSL, and a short option's value can be attached like -XPOST.
    def short_options(word, words)
      letters = word.delete_prefix('-')
      args = []

      letters.each_char.with_index do |letter, index|
        option = "-#{letter}"
        next args << FLAGS[option] if FLAGS.key?(option)
        raise Error, "curl's #{option} option isn't allowed in endpoint snippets" unless VALUE_OPTIONS.key?(option)

        # The value is the rest of the word, or else the next word.
        attached = letters[(index + 1)..]
        words.unshift(attached) unless attached.empty?
        return args.concat(long_option(VALUE_OPTIONS[option], words))
      end

      args
    end

    def value(option, value)
      case VALUE_CHECKS.fetch(option)
      when :url then url(value)
      when :no_file then no_file(option, value, value.start_with?('@'))
      when :no_urlencoded_file then no_file(option, value, value.match?(/\A[^=]*@/))
      else value
      end
    end

    def no_file(option, value, reads_file)
      raise Error, "curl's #{option} can't read a file (#{value}) in endpoint snippets" if reads_file

      value
    end

    def url(value)
      raise Error, "Endpoint snippets can only request http(s) URLs, not #{value}" unless value.match?(URL)

      value
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
