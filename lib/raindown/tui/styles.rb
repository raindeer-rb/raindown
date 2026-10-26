# frozen_string_literal: true

require 'curses'

module Raindown
  module TUI
    # The curses attributes of a Layout's styles. The title is white on blue, and the selected row white on a lighter
    # blue, while other colours are on the terminal's own background. Without colours, they're in reverse.
    module Styles
      COLORS = { directive: Curses::COLOR_CYAN, button: Curses::COLOR_YELLOW, error: Curses::COLOR_RED,
                 folder: Curses::COLOR_BLUE }.freeze
      # The title's and the selected row's blues, from the 256 colours most terminals have, or the 8 they all do.
      BLUES = { title: 25, selected: 33 }.freeze
      BASIC_BLUES = { title: Curses::COLOR_BLUE, selected: Curses::COLOR_CYAN }.freeze
      BRIGHT_WHITE = 15

      module_function

      # Sets up the colours, once the screen has started, and returns the attribute of each style.
      def start
        return plain unless Curses.has_colors?

        start_colors
        colored
      end

      def plain
        { title: Curses::A_REVERSE | Curses::A_BOLD, selected: Curses::A_REVERSE, selected_button: Curses::A_REVERSE,
          cursor: Curses::A_UNDERLINE, heading: Curses::A_BOLD, body: Curses::A_DIM, error: Curses::A_BOLD,
          button: Curses::A_BOLD, folder: Curses::A_BOLD, project: Curses::A_BOLD, dashboard: Curses::A_BOLD,
          key: Curses::A_REVERSE, border: Curses::A_DIM }
      end

      def colored
        plain.merge(
          title: pair(:title) | Curses::A_BOLD, selected: pair(:selected) | white_bold,
          selected_button: pair(:selected_button) | Curses::A_BOLD, directive: pair(:directive),
          error: pair(:error) | Curses::A_BOLD, button: pair(:button) | Curses::A_BOLD,
          folder: pair(:folder) | Curses::A_BOLD, project: pair(:directive) | Curses::A_BOLD,
          dashboard: pair(:directive) | Curses::A_BOLD
        )
      end

      # Each colour pair as [name, foreground, background], where -1 is the terminal's own background.
      def pairs
        many = Curses.colors >= 256
        blues = many ? BLUES : BASIC_BLUES
        white = many ? BRIGHT_WHITE : Curses::COLOR_WHITE

        [*COLORS.map { |name, color| [name, color, -1] }, [:title, white, blues[:title]],
         [:selected, white, blues[:selected]], [:selected_button, Curses::COLOR_YELLOW, blues[:selected]]]
      end

      def pair(name)
        Curses.color_pair(pairs.index { it.first == name } + 1)
      end

      # The 8 colour white is grey, which bold brightens.
      def white_bold
        Curses.colors >= 256 ? Curses::A_NORMAL : Curses::A_BOLD
      end

      def start_colors
        Curses.start_color
        Curses.use_default_colors
        pairs.each.with_index(1) { |(_name, foreground, background), index| Curses.init_pair(index, foreground, background) }
      end
    end
  end
end
