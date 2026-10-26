# frozen_string_literal: true

require 'curses'
require 'unicode/display_width'

module Raindown
  module TUI
    # Turns curses' keys and clicks into a Navigator's events.
    module Input
      KEYS = {
        Curses::KEY_UP => :up, 'k' => :up, Curses::KEY_DOWN => :down, 'j' => :down,
        Curses::KEY_LEFT => :left, 'h' => :left, Curses::KEY_RIGHT => :right, 'l' => :right,
        "\t" => :tab, Curses::KEY_BTAB => :tab, "\r" => :enter, "\n" => :enter, Curses::KEY_ENTER => :enter,
        ' ' => :toggle, 'x' => :execute, 'e' => :edit, 'w' => :write_back, 'r' => :reload, 'q' => :quit
      }.freeze

      module_function

      # A key from getch, which is a string for a printable character and otherwise a number.
      def key_event(key)
        key = key.chr if key.is_a?(Integer) && key < 256
        KEYS[key]
      end

      # A scroll of the wheel moves the cursor, and a click sends the event of what's under it.
      def mouse_event(event, zones)
        wheel.find { |button, _| event.bstate.anybits?(button) }&.last || click(zones, column: event.x, row: event.y)
      end

      # Older ncurses has no fifth button, which is the wheel scrolling down.
      def wheel
        { Curses::BUTTON4_PRESSED => :up }.tap do |buttons|
          buttons[Curses::BUTTON5_PRESSED] = :down if Curses.const_defined?(:BUTTON5_PRESSED)
        end
      end

      # Where each of a Layout's segments with an event is on the screen, as [row, columns, event].
      def zones(lines)
        lines.each_with_index.flat_map do |segments, row|
          column = 0
          segments.filter_map do |segment|
            width = Unicode::DisplayWidth.of(segment.text)
            zone = [row, column...(column + width), segment.event] if segment.event
            column += width
            zone
          end
        end
      end

      def click(zones, column:, row:)
        zones.find { |zone_row, columns, _event| zone_row == row && columns.cover?(column) }&.last
      end
    end
  end
end
