# frozen_string_literal: true

module Raindown
  module TUI
    # How a Navigator's focus and cursor move: Tab or left and right between the files and the outline or dashboard,
    # and up and down in the pane with the focus.
    module Focus
      private

      def other_pane
        @focus == :files ? main_pane : :files
      end

      def move(by)
        @panes[@focus].move(by)
        nil
      end

      def switch(pane)
        @focus = pane
        nil
      end
    end
  end
end
