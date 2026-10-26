# frozen_string_literal: true

require 'curses'

require_relative 'input'
require_relative 'layout'
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

      private

      def perform(name, *args)
        case name
        when :run
          suspend { system(*args.first) }
          @navigator.ran
        when :wait
          message, task = args
          show(message)
          task.call
        end
      end

      def start
        ENV['ESCDELAY'] ||= '25'
        Curses.init_screen
        @styles = Styles.start
        Curses.noecho
        Curses.cbreak
        Curses.nonl
        Curses.curs_set(0)
        Curses.stdscr.keypad(true)
        Curses.stdscr.timeout = TICK
        Curses.mousemask(Curses::BUTTON1_PRESSED | Curses::BUTTON1_CLICKED | Input.wheel.keys.sum)
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

        window.refresh
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

      def mouse
        event = Curses.getmouse
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
