# frozen_string_literal: true

require 'curses'

module Raindown
  module TUI
    # The curses attributes of a Layout's styles. Text is periwinkle where there are 256 colours, and the terminal's own
    # colour otherwise, while the title, headings, and the lines between the panes and beneath the title are cornflower
    # blue. The selected
    # row is white on blue, or on dark grey in the panes without the focus, while other colours are on the terminal's own
    # background.
    # With only 8 colours, there's no dark grey, so those rows are underlined, and without colours,
    # the rest are in reverse.
    module Styles
      COLORS = { button: Curses::COLOR_YELLOW, error: Curses::COLOR_RED }.freeze
      # Directives, like charts' on the Dashboard, in purple, and the folders, projects and pages in the files, the title,
      # and headings, like the outline's and the Dashboard cards', in cornflower blue, and the waffle's syrup in brown,
      # from the 256 colours most terminals
      # have, or magenta and blue with 8.
      CORNFLOWER = 111
      ACCENTS = { directive: 141, folder: CORNFLOWER, title: CORNFLOWER, heading: CORNFLOWER, syrup: 130 }.freeze
      BASIC_ACCENTS = { directive: Curses::COLOR_MAGENTA, folder: Curses::COLOR_BLUE, title: Curses::COLOR_BLUE,
                        heading: Curses::COLOR_BLUE, syrup: Curses::COLOR_YELLOW }.freeze

      # The green of GET, and of a selected method in Code feelings that's already been felt.
      GREEN = 34

      # The colours of endpoints' HTTP methods, like GET in green, from the 256 colours most terminals have,
      # which are the same in every theme, unlike the 8 they all do, where green can look yellow.
      METHODS = { get: GREEN, post: 33, delete: 196, put: 220, patch: 171, head: 44, options: 44 }.freeze
      BASIC_METHODS = { get: Curses::COLOR_GREEN, post: Curses::COLOR_BLUE, delete: Curses::COLOR_RED,
                        put: Curses::COLOR_YELLOW, patch: Curses::COLOR_MAGENTA, head: Curses::COLOR_CYAN,
                        options: Curses::COLOR_CYAN }.freeze

      # Highlighted code's colours, by the kind of token, from the 256 colours most terminals have, or the 8 they all do,
      # where comments are dim instead of grey.
      CODE = { code_keyword: 204, code_string: 114, code_number: 179, code_function: 75, code_constant: 117,
               code_comment: 244 }.freeze
      BASIC_CODE = { code_keyword: Curses::COLOR_MAGENTA, code_string: Curses::COLOR_GREEN, code_number: Curses::COLOR_YELLOW,
                     code_function: Curses::COLOR_BLUE, code_constant: Curses::COLOR_CYAN, code_comment: Curses::COLOR_WHITE }.freeze

      # Code feelings' bright colours, for its rain and fireworks, from the 256 colours most terminals have, or
      # the 8 they all do.
      BRIGHT = { bright_red: 203, bright_orange: 215, bright_yellow: 227, bright_green: 120, bright_cyan: 87,
                 bright_blue: 75, bright_purple: 177, bright_pink: 213 }.freeze
      BASIC_BRIGHT = { bright_red: Curses::COLOR_RED, bright_orange: Curses::COLOR_YELLOW, bright_yellow: Curses::COLOR_YELLOW,
                       bright_green: Curses::COLOR_GREEN, bright_cyan: Curses::COLOR_CYAN, bright_blue: Curses::COLOR_BLUE,
                       bright_purple: Curses::COLOR_MAGENTA, bright_pink: Curses::COLOR_MAGENTA }.freeze

      # The selected row's blue, the green of a selected method in Code feelings that's already been felt, and the
      # cornflower blue of the lines between the panes and beneath the title, from the 256 colours most terminals have,
      # or the 8 they all do.
      BLUES = { selected: 33, felt: GREEN, line: CORNFLOWER }.freeze
      BASIC_BLUES = { selected: Curses::COLOR_CYAN, felt: Curses::COLOR_GREEN, line: Curses::COLOR_BLUE }.freeze

      # Text that has no colour of its own, from the 256 colours most terminals have, or the terminal's own with 8.
      PERIWINKLE = 147

      # Code feelings' text and lines, in lavender, or magenta in 8 colours, the purple its magnified digits take turns
      # with, or blue, and a pale, envious tint, for envious methods' digits, or cyan.
      FEELINGS = { feelings: 183, feelings_purple: 135, envy: 152 }.freeze
      BASIC_FEELINGS = { feelings: Curses::COLOR_MAGENTA, feelings_purple: Curses::COLOR_BLUE, envy: Curses::COLOR_CYAN }.freeze
      BRIGHT_WHITE = 15
      DARK_GREY = 238

      # Code feelings' red when the screen's too small for it, or the 8 colours' red.
      DARK_RED = 88

      module_function

      # Sets up the colours, once the screen has started, and returns the attribute of each style.
      def start
        return plain unless Curses.has_colors?

        start_colors
        colored
      end

      # Without colours, a style that isn't here is the terminal's own.
      def plain
        Hash.new(Curses::A_NORMAL).merge(
          title: Curses::A_REVERSE | Curses::A_BOLD, selected: Curses::A_REVERSE, too_small: Curses::A_REVERSE,
          feelings_selected: Curses::A_REVERSE | Curses::A_BOLD, felt_selected: Curses::A_REVERSE | Curses::A_BOLD,
          selected_button: Curses::A_REVERSE,
          cursor: Curses::A_UNDERLINE, cursor_button: Curses::A_UNDERLINE | Curses::A_BOLD, heading: Curses::A_BOLD,
          body: Curses::A_DIM, error: Curses::A_BOLD, button: Curses::A_BOLD, folder: Curses::A_BOLD, project: Curses::A_BOLD, page: Curses::A_BOLD,
          key: Curses::A_REVERSE, border: Curses::A_DIM, divider: Curses::A_BOLD,
          code_keyword: Curses::A_BOLD, code_comment: Curses::A_DIM, envy: Curses::A_DIM
        )
      end

      def colored
        in_text_color.merge(
          title: pair(:title) | Curses::A_BOLD, directive: pair(:directive), error: pair(:error) | Curses::A_BOLD,
          button: pair(:button) | Curses::A_BOLD, **selections, **emphasis, **dividers, **code_tokens, **bright, **files,
          **unfocused
        )
      end

      # The selected row, its buttons, Code feelings' selected method, bold, on green when it's already been felt, and its
      # red when the screen's too small for it.
      def selections
        { selected: pair(:selected) | white_bold, feelings_selected: pair(:selected) | Curses::A_BOLD,
          felt_selected: pair(:felt_selected) | Curses::A_BOLD,
          too_small: pair(:too_small) | white_bold, selected_button: pair(:selected_button) | Curses::A_BOLD }
      end

      # The styles without a colour of their own, or that are only bold, dim or the like, in the text's colour, which is
      # also any style that isn't here.
      def in_text_color
        text = pair(:text)
        Hash.new(text).merge(plain.transform_values { it | text })
      end

      # Headings, the waffle's butter's shine and its syrup, and Code feelings' text and lines, and its envious methods, bold around
      # the method the mouse is over, and its purple.
      def emphasis
        { heading: pair(:heading) | Curses::A_BOLD, feelings: pair(:feelings), nearby: pair(:feelings) | Curses::A_BOLD,
          envy: pair(:envy), envy_nearby: pair(:envy) | Curses::A_BOLD,
          feelings_purple: pair(:feelings_purple), shine: pair(:shine) | Curses::A_BOLD, syrup: pair(:syrup) }
      end

      # Highlighted code's tokens, like keywords and comments, with comments dim in 8 colours, where there's no grey.
      def code_tokens
        tokens = CODE.keys.to_h { [it, pair(it)] }
        tokens[:code_comment] |= Curses::A_DIM if Curses.colors < 256
        tokens
      end

      # The bright colours, bold, so they're bright in 8 colours too.
      def bright = BRIGHT.keys.to_h { [it, pair(it) | Curses::A_BOLD] }

      # The lines between the panes and beneath the title.
      def dividers = { divider: pair(:divider) }

      def files
        { folder: pair(:folder) | Curses::A_BOLD, project: pair(:folder) | Curses::A_BOLD,
          page: pair(:folder) | Curses::A_BOLD, **METHODS.keys.to_h { [:"method_#{it}", pair(:"method_#{it}") | Curses::A_BOLD] } }
      end

      # The selected rows of the panes without the focus, on dark grey where there's one.
      def unfocused
        return { cursor_button: pair(:button) | Curses::A_BOLD } unless Curses.colors >= 256

        { cursor: pair(:cursor), cursor_button: pair(:cursor_button) | Curses::A_BOLD }
      end

      # Each colour pair as [name, foreground, background], where -1 is the terminal's own background.
      def pairs
        many = Curses.colors >= 256
        blues = many ? BLUES : BASIC_BLUES
        white = many ? BRIGHT_WHITE : Curses::COLOR_WHITE
        text = many ? PERIWINKLE : -1

        [*COLORS.map { |name, color| [name, color, -1] },
         *(many ? METHODS : BASIC_METHODS).map { |name, color| [:"method_#{name}", color, -1] },
         *(many ? CODE.merge(BRIGHT, FEELINGS, ACCENTS) : BASIC_CODE.merge(BASIC_BRIGHT, BASIC_FEELINGS, BASIC_ACCENTS))
           .map { |name, color| [name, color, -1] },
         [:text, text, -1],
         [:selected, white, blues[:selected]], [:felt_selected, white, blues[:felt]], [:too_small, white, many ? DARK_RED : Curses::COLOR_RED],
         [:selected_button, Curses::COLOR_YELLOW, blues[:selected]],
         [:cursor, white, DARK_GREY], [:cursor_button, Curses::COLOR_YELLOW, DARK_GREY], [:divider, blues[:line], -1],
         [:shine, white, -1]]
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
