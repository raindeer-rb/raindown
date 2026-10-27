# frozen_string_literal: true

require 'curses'

module Raindown
  module TUI
    # The curses attributes of a Layout's styles. The title is white on blue, and the selected row white on a lighter
    # blue, or on dark grey in the panes without the focus, while other colours are on the terminal's own background.
    # With only 8 colours, there's no dark grey, so those rows are underlined, and without colours,
    # the rest are in reverse.
    module Styles
      COLORS = { directive: Curses::COLOR_CYAN, button: Curses::COLOR_YELLOW, error: Curses::COLOR_RED,
                 folder: Curses::COLOR_BLUE }.freeze
      # The colours of endpoints' HTTP methods, like GET in green, from the 256 colours most terminals have,
      # which are the same in every theme, unlike the 8 they all do, where green can look yellow.
      METHODS = { get: 40, post: 33, delete: 196, put: 220, patch: 171, head: 44, options: 44 }.freeze
      BASIC_METHODS = { get: Curses::COLOR_GREEN, post: Curses::COLOR_BLUE, delete: Curses::COLOR_RED,
                        put: Curses::COLOR_YELLOW, patch: Curses::COLOR_MAGENTA, head: Curses::COLOR_CYAN,
                        options: Curses::COLOR_CYAN }.freeze
      # Highlighted code's colours, by the kind of token, from the 256 colours most terminals have, or the 8 they all do,
      # where comments are dim instead of grey.
      CODE = { code_keyword: 204, code_string: 114, code_number: 179, code_function: 75, code_constant: 117,
               code_comment: 244 }.freeze
      BASIC_CODE = { code_keyword: Curses::COLOR_MAGENTA, code_string: Curses::COLOR_GREEN, code_number: Curses::COLOR_YELLOW,
                     code_function: Curses::COLOR_BLUE, code_constant: Curses::COLOR_CYAN, code_comment: Curses::COLOR_WHITE }.freeze
      # The title's and the selected row's blues, from the 256 colours most terminals have, or the 8 they all do.
      BLUES = { title: 25, selected: 33 }.freeze
      BASIC_BLUES = { title: Curses::COLOR_BLUE, selected: Curses::COLOR_CYAN }.freeze
      BRIGHT_WHITE = 15
      DARK_GREY = 238

      module_function

      # Sets up the colours, once the screen has started, and returns the attribute of each style.
      def start
        return plain unless Curses.has_colors?

        start_colors
        colored
      end

      def plain
        { title: Curses::A_REVERSE | Curses::A_BOLD, selected: Curses::A_REVERSE, selected_button: Curses::A_REVERSE,
          cursor: Curses::A_UNDERLINE, cursor_button: Curses::A_UNDERLINE | Curses::A_BOLD, heading: Curses::A_BOLD,
          body: Curses::A_DIM, error: Curses::A_BOLD, button: Curses::A_BOLD, folder: Curses::A_BOLD, project: Curses::A_BOLD, dashboard: Curses::A_BOLD,
          key: Curses::A_REVERSE, border: Curses::A_DIM, run: Curses::A_REVERSE | Curses::A_BOLD, divider: Curses::A_BOLD,
          selected_divider: Curses::A_REVERSE, cursor_divider: Curses::A_BOLD, hover: Curses::A_BOLD,
          code_keyword: Curses::A_BOLD, code_comment: Curses::A_DIM }
      end

      def colored
        plain.merge(
          title: pair(:title) | Curses::A_BOLD, selected: pair(:selected) | white_bold,
          selected_button: pair(:selected_button) | Curses::A_BOLD, directive: pair(:directive),
          error: pair(:error) | Curses::A_BOLD, button: pair(:button) | Curses::A_BOLD, **emphasis,
          **dividers, **code, **files, **unfocused
        )
      end

      # The Run button, and what the mouse is over, like Code feelings' digits in bold blue.
      def emphasis = { run: pair(:run) | Curses::A_BOLD, hover: pair(:hover) | Curses::A_BOLD }

      # Highlighted code, with comments dim in 8 colours, where there's no grey.
      def code
        code = CODE.keys.to_h { [it, pair(it)] }
        code[:code_comment] |= Curses::A_DIM if Curses.colors < 256
        code
      end

      # The line between the panes, and where it meets a selected row.
      def dividers = { divider: pair(:divider), selected_divider: pair(:selected_divider) }

      def files
        { folder: pair(:folder) | Curses::A_BOLD, project: pair(:directive) | Curses::A_BOLD,
          dashboard: pair(:directive) | Curses::A_BOLD, **METHODS.keys.to_h { [:"method_#{it}", pair(:"method_#{it}") | Curses::A_BOLD] } }
      end

      # The selected rows of the panes without the focus, on dark grey where there's one.
      def unfocused
        return { cursor_button: pair(:button) | Curses::A_BOLD, cursor_divider: pair(:divider) } unless Curses.colors >= 256

        { cursor: pair(:cursor), cursor_button: pair(:cursor_button) | Curses::A_BOLD, cursor_divider: pair(:cursor_divider) }
      end

      # Each colour pair as [name, foreground, background], where -1 is the terminal's own background.
      def pairs
        many = Curses.colors >= 256
        blues = many ? BLUES : BASIC_BLUES
        white = many ? BRIGHT_WHITE : Curses::COLOR_WHITE

        [*COLORS.map { |name, color| [name, color, -1] },
         *(many ? METHODS : BASIC_METHODS).map { |name, color| [:"method_#{name}", color, -1] },
         *(many ? CODE : BASIC_CODE).map { |name, color| [name, color, -1] },
         [:title, white, blues[:title]],
         [:selected, white, blues[:selected]], [:selected_button, Curses::COLOR_YELLOW, blues[:selected]],
         [:cursor, white, DARK_GREY], [:cursor_button, Curses::COLOR_YELLOW, DARK_GREY], [:divider, blues[:title], -1],
         [:selected_divider, blues[:title], blues[:selected]], [:cursor_divider, blues[:title], DARK_GREY],
         [:run, white, Curses::COLOR_GREEN], [:hover, blues[:selected], -1]]
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
