# frozen_string_literal: true

require 'curses'

module Raindown
  module TUI
    # ncurses before 6.1, like macOS's, repeats a character with the terminal's rep capability by writing one byte of it,
    # so a run of █ in a bar chart draws as ?. Terminals with their own terminfo entries, like Ghostty's and kitty's,
    # have rep, while the system's entries from those ncurses versions don't. So with old ncurses, a terminal whose
    # entry isn't the system's starts curses as xterm-256color, which they draw the same, and TERM is put back after,
    # for the commands run from the screen, like the editor.
    module NcursesShim
      FALLBACK = 'xterm-256color'
      SYSTEM_TERMINFO = %w[/usr/share/terminfo /usr/lib/terminfo /lib/terminfo].freeze
      FIXED_VERSION = [6, 1].freeze

      module_function

      def starting(version: Curses::VERSION)
        term = ENV.fetch('TERM', nil)
        ENV['TERM'] = FALLBACK if fallback?(term, version)
        yield
      ensure
        ENV['TERM'] = term
      end

      def fallback?(term, version)
        return false if term.nil? || term.empty? || term == FALLBACK

        old?(version) && !system_entry?(term)
      end

      def old?(version)
        numbers = version.to_s[/ncurses (\d+)\.(\d+)/, 0]&.scan(/\d+/)&.map(&:to_i)
        numbers ? (numbers <=> FIXED_VERSION).negative? : false
      end

      # Entries are in a folder named by their first letter, or on macOS, its hex code, like 78/xterm-256color.
      def system_entry?(term)
        SYSTEM_TERMINFO.any? do |folder|
          [term[0], term[0].ord.to_s(16)].any? { File.exist?(File.join(folder, it, term)) }
        end
      end
    end
  end
end
