# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'projects'

module Raindown
  # Sketches from Claude Code's replies, kept in a project's .raindown/sketches.md, which the terminal UI's Sketches page
  # shows, newest first. Each is a code block under a heading of when it was saved and its kind:
  #   ## 2026-10-30T03:14:07Z · mockup
  #
  #   ```mockup
  #   ╭──────╮
  #   │ Idea │
  #   ╰──────╯
  #   ```
  # A sketch is a code block marked with its kind, like "mockup", or one with no language that's drawn, with box-drawing
  # lines or blocks, whose kind is worked out from what it's drawn with when it's saved (see Sketches.kind).
  module Sketches
    Sketch = Data.define(:time, :kind, :lines, :line)

    FILE = File.join('.raindown', 'sketches.md')
    # The kinds, in the order the page's filter lists them, by their names there.
    KINDS = { 'mockup' => 'Mockups', 'diagram' => 'Diagrams', 'chart' => 'Charts', 'table' => 'Tables', 'other' => 'Other' }.freeze
    DRAWN = /[─━│┃┌┐└┘├┤┬┴┼╭╮╯╰═║╔╗╚╝▁▂▃▄▅▆▇█▏▔▕░▒▓╱╲]/
    BLOCK = /^```(\w*)\n(.*?)^```$/m
    # Arrows that join things, across, which make a sketch a diagram, like a flow chart's or a sequence diagram's.
    ACROSS = /─▶|◀─|─>|<─|->|<-|[→←↔]/
    # Arrows that join things up or down, when there's a line above or below them.
    UP_DOWN = %w[▼ ▲].freeze
    BLOCKS = /[▁▂▃▄▅▆▇█░▒▓]/
    # The share of a sketch's characters that are blocks, from which it's a chart.
    CHART = 0.25
    SEPARATOR = ' · '

    module_function

    # The project's sketches, newest first, each with the line its drawing starts on, counting from 1, like an editor.
    def read(root)
      path = File.join(root, FILE)
      return [] unless File.exist?(path)

      lines = File.readlines(path, chomp: true)
      starts = lines.each_index.select { lines[it].start_with?('## ') }
      starts.filter_map { |start| sketch(lines, start) }.reverse
    end

    # Saves the sketches in Claude Code's last reply, from its Stop hook's JSON, to the project it's working in, if any,
    # each with its kind.
    def save(hook)
      root = Projects.root(hook['cwd'].to_s) || return
      drawn = drawn(last_reply(hook['transcript_path'].to_s))
      return if drawn.empty?

      time = Time.now.utc.iso8601
      File.open(File.join(root, FILE), 'a') do |file|
        drawn.each { |kind, body| file.write("## #{time}#{SEPARATOR}#{kind}\n\n```#{kind}\n#{body}```\n\n") }
      end
    end

    # The text's code blocks that are sketches, each with its kind.
    def drawn(text)
      text.scan(BLOCK).filter_map do |language, body|
        next [language, body] if KINDS.key?(language)

        [kind(body.lines(chomp: true)), body] if language.empty? && body.match?(DRAWN)
      end
    end

    # What a sketch is, from what it's drawn with: a diagram when arrows join its parts, a chart when it's mostly blocks,
    # a table when its lines cross, a mockup when it's otherwise boxes and lines, and other when it's none of those.
    def kind(lines)
      text = lines.join("\n")
      return 'diagram' if text.match?(ACROSS) || joined_up_or_down?(lines)
      return 'chart' if text.scan(BLOCKS).length >= CHART * text.delete(" \n").length
      return 'table' if text.include?('┼')
      return 'mockup' if text.match?(DRAWN)

      'other'
    end

    # Whether an up or down arrow has a line above or below it, joining it to what it points from.
    def joined_up_or_down?(lines)
      lines.each_with_index.any? do |line, index|
        line.each_char.with_index.any? do |char, column|
          UP_DOWN.include?(char) && [lines[index - 1], lines[index + 1]].any? { it&.[](column) == '│' }
        end
      end
    end

    # The text of the assistant's messages since the last thing the user typed, in a transcript of JSON lines.
    def last_reply(path)
      return '' unless File.exist?(path)

      entries = File.readlines(path).filter_map { entry(it) }
      asked = entries.rindex { it['type'] == 'user' && typed?(it.dig('message', 'content')) } || -1
      entries[(asked + 1)..].select { it['type'] == 'assistant' }.flat_map { texts(it.dig('message', 'content')) }.join("\n")
    end

    # A line of the transcript, or nil for one that isn't JSON, like one still being written.
    def entry(line)
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end

    # A user's message is typed when it's text, rather than a tool's result.
    def typed?(content) = content.is_a?(String) || Array(content).any? { it['type'] == 'text' }

    def texts(content) = Array(content).filter_map { it['text'] if it.is_a?(Hash) && it['type'] == 'text' }

    def sketch(lines, start)
      time, kind = lines[start].delete_prefix('## ').split(SEPARATOR, 2)
      opening = (start + 1...lines.length).find { lines[it].start_with?('```') } || return
      closing = (opening + 1...lines.length).find { lines[it] == '```' } || return
      kind = 'other' unless KINDS.key?(kind)
      Sketch.new(time:, kind:, lines: lines[(opening + 1)...closing], line: opening + 2)
    end
  end
end
