# frozen_string_literal: true

require_relative 'list_renderer'

module Raindown
  module TUI
    # The open file's outline, right of the files: a row on each line, with its buttons.
    class OutlineRenderer < ListRenderer
      BUTTONS = [['Tab', 'Pane', :tab], ['Enter', 'Open', :enter], ['x', 'Run', :execute], ['e', 'Edit', :edit],
                 ['w', 'Write back', :write_back], ['r', 'Reload', :reload], ['q', 'Quit', :quit]].freeze

      def buttons = BUTTONS

      def page
        if navigator.path then navigator.relative(navigator.path)
        else 'No Markdown files'
        end
      end
    end
  end
end
