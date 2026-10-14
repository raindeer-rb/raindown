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
  # Nodes like toc: and files: render before this, and directives whose output is HTML render in the HTML afterwards.
  module PreRenderer
    BLOCK_DIRECTIVES = %w[for if list].freeze
    # A variable like <{ title }> or a for, if or list directive, which render here.
    DIRECTIVE = /<\{\s*(?:(?:#{BLOCK_DIRECTIVES.join('|')}):[^}]*|:(?:#{BLOCK_DIRECTIVES.join('|')})|[@\w.]+)\s*\}>/
    # A for, if or list directive alone on its line, which leaves no line behind, so a loop's list items stay together.
    BLOCK_LINE = /^[ \t]*(<\{\s*:?(?:#{BLOCK_DIRECTIVES.join('|')})\b[^}]*\}>)[ \t]*\n/
    HIDDEN = /\u{E002}(\d+)\u{E003}/

    module_function

    def render(markdown, variables:, metadata: {}, bare: false)
      markdown = BareDirectives.expand(markdown) if bare
      return markdown unless markdown.include?('{')

      markdown = Code.hide_braces(markdown.dup.force_encoding('UTF-8'))
      body = FrontMatter.parse(markdown).last
      "#{markdown.delete_suffix(body)}#{render_body(body, variables, metadata)}"
    end

    def render_body(body, variables, metadata)
      hidden = []
      # Other directives are hidden, but not the Markdown between their tags.
      template = body.gsub(/<\{.*?\}>|<\{/) { |directive| directive.match?(/\A#{DIRECTIVE}\z/) ? directive : hide(directive, hidden) }
      template = template.gsub(BLOCK_LINE, '\1')
      return body unless template.include?('{')

      # Antlers strips the whitespace around a template, which can be Markdown, like an indented code block.
      leading = template[/\A\s*/]
      trailing = template[/\s*\z/]
      ast = Antlers.ast(template:, elements: Antlers::Elements[:html, :var, :if, :for] + Elements[:list])
      rendered = Antlers.render(ast:, current_binding: variables.binding, metadata:)

      "#{leading}#{rendered}#{trailing}".gsub(HIDDEN) { hidden[::Regexp.last_match(1).to_i] }
    end

    def hide(directive, hidden)
      hidden << directive
      "\u{E002}#{hidden.length - 1}\u{E003}"
    end
  end
end
