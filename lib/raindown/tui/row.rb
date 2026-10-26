# frozen_string_literal: true

module Raindown
  module TUI
    # A line of a pane. Target is what it's about: a folder or file path, a Heading or Directive, or a line number.
    # Buttons are [label, event] pairs, like ['[Run]', :execute].
    Row = Data.define(:text, :depth, :kind, :target, :buttons) do
      def initialize(buttons: [], **) = super

      # The line the editor opens at for the row.
      def line
        target.is_a?(Integer) ? target : target.line
      end
    end
  end
end
