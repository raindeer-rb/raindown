# frozen_string_literal: true

module Raindown
  module TUI
    # How a Navigator's focus and cursor move: Tab or left and right between the files and the view,
    # and up and down in the pane with the focus.
    module Focus
      private

      def other_pane
        @focus == :nav ? :main : :nav
      end

      def move(by)
        content(@focus).move(by)
        nil
      end

      def switch(pane)
        @focus = pane
        nil
      end
    end
  end
end
