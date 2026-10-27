# frozen_string_literal: true

module Raindown
  module TUI
    # A ListView's rows in its pane, like the files in the nav or a file's outline, each with its buttons.
    class ListRenderer < Renderer
      def lines
        list = navigator.content(pane).visible(height)
        Array.new(height) { |index| cell(pane, *list, index, width) }
      end
    end
  end
end
