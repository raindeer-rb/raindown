# frozen_string_literal: true

require 'curses'

module Raindown
  module TUI
    # The curses attributes of a Layout's styles, in colour on the terminal's own background when it has colours.
    module Styles
      COLORS = { directive: Curses::COLOR_CYAN, button: Curses::COLOR_YELLOW, error: Curses::COLOR_RED,
                 folder: Curses::COLOR_BLUE }.freeze

      module_function

      # Sets up the colours, once the screen has started, and returns the attribute of each style.
      def start
        colors = Curses.has_colors?
        start_colors if colors
        color = ->(name) { colors ? Curses.color_pair(COLORS.keys.index(name) + 1) : Curses::A_NORMAL }

        {
          title: Curses::A_REVERSE | Curses::A_BOLD, selected: Curses::A_REVERSE, cursor: Curses::A_UNDERLINE,
          heading: Curses::A_BOLD, directive: color[:directive], output: Curses::A_DIM,
          error: color[:error] | Curses::A_BOLD, button: color[:button] | Curses::A_BOLD,
          selected_button: color[:button] | Curses::A_REVERSE, folder: color[:folder] | Curses::A_BOLD,
          key: Curses::A_REVERSE, border: Curses::A_DIM
        }
      end

      def start_colors
        Curses.start_color
        Curses.use_default_colors
        COLORS.each_value.with_index(1) { |color, pair| Curses.init_pair(pair, color, -1) }
      end
    end
  end
end
