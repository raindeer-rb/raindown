# frozen_string_literal: true

require 'curses'

require_relative 'input'
require_relative '../layout'
require_relative 'ncurses_shim'
require_relative 'quiet'
require_relative 'styles'

module Raindown
  module TUI
    # Paints a Navigator's Layout with curses, and sends the Navigator the events of keys and clicks, read with Input.
    # Only this class draws on the terminal, so another library could draw the same Layout.
    class Screen
      # How often, in milliseconds, the screen's drawn, and the open file checked for changes, while no key is pressed, by
      # the view's pace: every half second while it's active, drawn mostly as keys are pressed, at 10 frames a second
      # while it's reactive, like Code feelings' trembling digits, and at 20 during an animation, like Code feelings' rain.
      TICKS = { active: 500, reactive: 100, animation: 50 }.freeze

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
          break if take_events == :quit
        end
      rescue Interrupt
        nil
      ensure
        stop
      end

      # The Navigator takes the next event, then any others already waiting, like the mouse's many moves, before the
      # screen's drawn again, so drawing doesn't fall further and further behind them.
      def take_events
        event = Input.read(TICKS.fetch(@navigator.pace), zones: @zones, typing: @navigator.typing?)
        loop do
          effect = @navigator.next_step(event)
          return effect if effect == :quit

          perform(effect)
          event = Input.read(0, zones: @zones, typing: @navigator.typing?)
          return if event == :tick
        end
      end

      # Runs a command, like the editor, then tells the Navigator, or shows a message while a slow task runs.
      def perform(effect)
        case effect
        in Run(command:) then suspend { system(*command) }.then { @navigator.ran }
        in Wait(message:, task:) then show(message).then { task.call }
        else nil
        end
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
        Input.track_mouse
      end

      def stop
        Input.untrack_mouse
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
        window.attron(@styles[segment.style]) { window.addstr(segment.text) }
      end

      def last_line(segments)
        *rest, last = segments
        [*rest, last.with(text: last.text[0...-1])]
      end

      # Shows a message in the status line while something slow runs, like an endpoint's request.
      def show(message)
        window = Curses.stdscr
        window.setpos(Curses.lines - 2, 0)
        window.clrtoeol
        window.addstr(" #{message}"[0, Curses.cols])
        window.refresh
      end

      # Leaves the screen to the command, like the editor, and comes back to it after. The command isn't sent the
      # mouse's moves meanwhile.
      def suspend
        Curses.def_prog_mode
        Input.untrack_mouse
        Curses.close_screen
        yield
      ensure
        Curses.reset_prog_mode
        Input.track_mouse
        Curses.stdscr.clear
        Curses.refresh
      end
    end
  end
end
