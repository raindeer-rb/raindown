# frozen_string_literal: true

require 'antlers'
require_relative 'code_blocks'
require_relative 'front_matter'

module Raindown
  # Renders variables in headings before Commonmarker reads them, so a heading's id and its entry in a table of
  # contents come from its text, like "# Notes for {name}" becoming "Notes for Mark" with the id "notes-for-mark".
  module PreRenderer
    HEADING = /\A {0,3}\#{1,6}(?:[ \t]|$)/
    # A code span is left as-is, {var} is escaped and <{ var }> is raw.
    TOKEN = /(`+).*?\1|<\{\s*([@\w.]+)\s*\}>|\{\s*([@\w.]+)\s*\}/
    # Escaped as Markdown so a value like "C# *notes*" shows as written. Braces become the placeholders that code uses,
    # so Antlers doesn't read them as another variable.
    PUNCTUATION = %r{[!-/:-@\[-`|~]}

    module_function

    def render(markdown, variables:)
      return markdown unless markdown.include?('{')

      markdown = markdown.dup.force_encoding('UTF-8')
      body = FrontMatter.parse(markdown).last
      "#{markdown.delete_suffix(body)}#{render_body(body, variables)}"
    end

    def render_body(body, variables)
      lines = body.lines
      index = 0

      while index < lines.length
        if (block = CodeBlocks.at(lines, index))
          index = block[:close]
        elsif lines[index].match?(HEADING)
          lines[index] = render_heading(lines[index], variables)
        end

        index += 1
      end

      lines.join
    end

    def render_heading(line, variables)
      line.gsub(TOKEN) do |token|
        code, raw, escaped = ::Regexp.last_match.captures
        next token if code

        value = value(raw || escaped, variables).gsub(/[{}]/, CODE_BRACES)
        raw ? value : value.gsub(PUNCTUATION) { "\\#{it}" }
      end
    end

    def value(name, variables)
      ast = Antlers.ast(template: "<{ #{name} }>", elements: Antlers::Elements[:var])

      Antlers.render(ast:, current_binding: variables.binding)
    end
  end
end
