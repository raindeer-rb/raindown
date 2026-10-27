# frozen_string_literal: true

module Raindown
  module TUI
    # A line of a pane. Target is what it's about: a folder or file path, a Heading or Directive, or a line number.
    # Buttons are [label, event] pairs, like ['[Run]', :execute], and a tag is an Endpoint, whose method is before its text.
    # Open is the Navigator's next step on Enter, like an Open of a file, and fold, a block that folds or expands the row.
    Row = Data.define(:text, :depth, :kind, :target, :buttons, :tag, :open, :fold) do
      def initialize(buttons: [], tag: nil, open: nil, fold: nil, **) = super

      # A separator is space between a pane's sections, which the cursor skips and clicks don't reach.
      def selectable? = kind != :separator

      # The line the editor opens at for the row.
      def line
        target.is_a?(Integer) ? target : target.line
      end
    end
  end
end
