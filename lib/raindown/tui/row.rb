# frozen_string_literal: true

module Raindown
  module TUI
    # A line of a pane. Target is what it's about: a folder or file path, a Heading or Directive, or a line number.
    # Buttons are [label, event] pairs, like ['[Run]', :execute], and a tag is an Endpoint, whose method is before its text.
    # Open is the Navigator's next step on Enter, like an Open of a file, and fold, a block that folds or expands the row.
    # Code is the text highlighted, as [text, style] parts, for a line of code, like a directive's body.
    # Each optional field has a default, which is why initialize takes so many.
    Row = Data.define(:text, :depth, :kind, :target, :buttons, :tag, :open, :fold, :code) do
      def initialize(buttons: [], tag: nil, open: nil, fold: nil, code: nil, **) = super # rubocop:disable Metrics/ParameterLists

      # A separator is space between a pane's sections, which the cursor skips and clicks don't reach.
      def selectable? = kind != :separator

      # The line the editor opens at for the row.
      def line
        target.is_a?(Integer) ? target : target.line
      end
    end

    # Space between a pane's sections, like the Dashboard and the files.
    Row::SEPARATOR = Row.new(text: '', depth: 0, kind: :separator, target: nil)
  end
end
