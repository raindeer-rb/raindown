# frozen_string_literal: true

require_relative 'list_renderer'

module Raindown
  module TUI
    # The open file's outline, right of the files: a row on each line, with its buttons.
    class OutlineRenderer < ListRenderer
      BUTTONS = [['Tab', 'Pane', :tab], ['Enter', 'Open', :enter], ['x', 'Run', :execute], ['e', 'Edit', :edit],
                 ['w', 'Write back', :write_back], ['r', 'Reload', :reload], ['/', 'Search', :search], ['q', 'Quit', :quit]].freeze

      def buttons = BUTTONS

      def page
        return 'No Markdown files' unless navigator.path

        navigator.relative(navigator.path)
      end
    end
  end
end
