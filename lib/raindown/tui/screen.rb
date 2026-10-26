# frozen_string_literal: true

require 'curses'

require_relative 'input'
require_relative 'layout'
require_relative 'quiet'
require_relative 'ncurses_shim'
require_relative 'styles'

module Raindown
  module TUI
    # Paints a Navigator's Layout with curses, and sends the Navigator the events of keys and clicks, read with Input.
    # Only this class draws on the terminal, so another library could draw the same Layout.
    class Screen
      # How often, in milliseconds, the open file is checked for changes while no key is pressed.
      TICK = 500

      def initialize(navigator)
        @navigator = navigator
        @zones = []
      end

      def run
        Quiet.holding_stderr { loop_screen }
      end

      private

      def loop_screen
        start

        loop do
          draw
          effect = @navigator.handle(read)
          break if effect == :quit

          perform(*effect) if effect.is_a?(Array)
        end
      rescue Interrupt
        nil
      ensure
        stop
      end

      # Runs a command, like the editor, then tells the Navigator, or shows a message while a slow task runs.
      def perform(name, command_or_message, task = nil)
        return show(command_or_message).then { task.call } if name == :wait

        suspend { system(*command_or_message) }
        @navigator.ran
      end

      def start
        ENV['ESCDELAY'] ||= '25'
        NcursesShim.starting { Curses.init_screen }
        @styles = Styles.start
        Curses.noecho
        Curses.cbreak
        Curses.nonl
        Curses.curs_set(0)
        Curses.stdscr.keypad(true)
        Curses.stdscr.timeout = TICK
        # The terminal sends the app its mouse events, so scrolling doesn't scroll the terminal either.
        Curses.mousemask(Input::CLICKS)
        Curses.mouseinterval(0)
      end

      def stop
        Curses.close_screen
      end

      def draw
        lines = Layout.new(@navigator, width: Curses.cols, height: Curses.lines).lines
        @zones = Input.zones(lines)
        window = Curses.stdscr
        window.erase

        lines.each_with_index do |segments, row|
          window.setpos(row, 0)
          # Writing the bottom-right corner would scroll the screen, so the last line stops a column short.
          segments = last_line(segments) if row == Curses.lines - 1
          segments.each { |segment| paint(window, segment) }
        end

        repaint_title(lines.first, window)
        window.refresh
      end

      # The title's rain cloud is one column to ncurses, and two in terminals like iTerm and kitty, which would put
      # the rest of the title a column out when ncurses changes part of it. So when it changes, the screen is
      # repainted, and the title is written in one go.
      def repaint_title(title, window)
        text = title&.map(&:text)&.join
        window.redraw if @title && text != @title
        @title = text
      end

      def paint(window, segment)
        window.attron(@styles.fetch(segment.style, Curses::A_NORMAL)) { window.addstr(segment.text) }
      end

      def last_line(segments)
        *rest, last = segments
        [*rest, last.with(text: last.text[0...-1])]
      end

      # The next event, or :tick when no key is pressed in time, or nil for keys without one, like a resize.
      def read
        key = Curses.stdscr.getch
        return :tick if key.nil?
        return mouse if key == Curses::KEY_MOUSE

        Curses.stdscr.clear if key == Curses::KEY_RESIZE
        Input.key_event(key)
      end

      # The curses gem warns the first time it makes a MouseEvent, that it's "undefining the allocator" of the class.
      def mouse
        event = Quiet.quietly { Curses.getmouse }
        Input.mouse_event(event, @zones) if event
      end

      # Shows a message in the status line while something slow runs, like an endpoint's request.
      def show(message)
        window = Curses.stdscr
        window.setpos(Curses.lines - 2, 0)
        window.clrtoeol
        window.addstr(" #{message}"[0, Curses.cols])
        window.refresh
      end

      # Leaves the screen to the command, like the editor, and comes back to it after.
      def suspend
        Curses.def_prog_mode
        Curses.close_screen
        yield
      ensure
        Curses.reset_prog_mode
        Curses.stdscr.clear
        Curses.refresh
      end
    end
  end
end
