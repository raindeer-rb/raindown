# frozen_string_literal: true

require 'antlers'
require_relative '../elements'
require_relative 'bare_directives'
require_relative 'code'
require_relative 'front_matter'

module Raindown
  # Renders the directives whose output is Markdown, before Commonmarker reads it: variables, loops, conditions and lists.
  # So a loop's items become one Markdown list or table, and a heading's id and its entry in a table of contents
  # come from its text, like "# Notes for {name}" becoming "Notes for Mark" with the id "notes-for-mark".
  # Nodes like toc: and files: render before this. Components and endpoints render here too, as fragments of HTML
  # that Raindown puts back once the document is HTML.
  module PreRenderer
    BLOCK_DIRECTIVES = %w[for if list].freeze
    # A for, if or list directive alone on its line, which leaves no line behind, so a loop's list items stay together.
    BLOCK_LINE = /^[ \t]*(<\{\s*:?(?:#{BLOCK_DIRECTIVES.join('|')})\b[^}]*\}>)[ \t]*\n/

    module_function

    def render(markdown, variables:, metadata: {}, bare: false)
      markdown = BareDirectives.expand(markdown) if bare
      return markdown unless markdown.include?('{')

      markdown = Code.hide_braces(markdown.dup.force_encoding('UTF-8'))
      body = FrontMatter.parse(markdown).last
      "#{markdown.delete_suffix(body)}#{render_body(body, variables, metadata)}"
    end

    def render_body(body, variables, metadata)
      template = body.gsub(BLOCK_LINE, '\1')
      return body unless template.include?('{')

      # Antlers strips the whitespace around a template, which can be Markdown, like an indented code block.
      leading = template[/\A\s*/]
      trailing = template[/\s*\z/]
      # Components and endpoints render here too, where loop variables are in scope, and keep their HTML as fragments.
      elements = Antlers::Elements[:html, :var, :if, :for] + Elements[:list, :endpoint, :prop_component, :slot_component]
      rendered = Antlers.render(ast: Antlers.ast(template:, elements:), current_binding: variables.binding, metadata:)

      "#{leading}#{rendered}#{trailing}"
    end
  end
end
