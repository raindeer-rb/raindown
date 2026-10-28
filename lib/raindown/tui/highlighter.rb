# frozen_string_literal: true

module Raindown
  module TUI
    # Code coloured with Rouge, which knows over 200 languages, as each line's [text, style] parts. Each part's style is
    # the kind of token it is, like a keyword or a string, from the few code styles Styles has, so they work in any
    # terminal. Code in a language Rouge doesn't know is a plain part a line.
    module Highlighter
      # Each kind of token's style, by the start of its name, like Literal.String.Double for a string, most specific first.
      STYLES = [['Name.Function', :code_function], ['Name.Class', :code_constant], ['Name.Constant', :code_constant],
                ['Name.Builtin', :code_constant], ['Name.Label', :code_constant], ['Keyword', :code_keyword],
                ['Literal.String', :code_string], ['Literal.Number', :code_number], ['Comment', :code_comment]].freeze

      module_function

      # The lines highlighted for a file's name, like shapes.rb, or a code fence's language, like json. Markdown
      # highlights the code in its fences in their own languages, like an endpoint's request and response.
      def lines(lines, filename: nil, language: nil)
        lexer = lexer(filename:, language:)
        return lines.map { [[it, :code]] } unless lexer

        lexer.lex(lines.join("\n")).each_with_object([[]]) do |(token, text), highlighted|
          text.split(/(\n)/).each do |piece|
            next highlighted << [] if piece == "\n"

            highlighted.last << [piece, style(token)] unless piece.empty?
          end
        end
      end

      # Rouge takes about a third of a second to load, so the TUI loads it when it starts, rather than with its code.
      def lexer(filename:, language:)
        require 'rouge'
        lexer = Rouge::Lexer.find_fancy(language) unless language.to_s.empty?
        lexer ||= Rouge::Lexer.guess_by_filename(filename).new if filename
        lexer unless lexer.is_a?(Rouge::Lexers::PlainText)
      end

      def style(token)
        name = token.qualname
        STYLES.find { |prefix, _| name.start_with?(prefix) }&.last || :code
      end
    end
  end
end
