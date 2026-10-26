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
        ' ' => :toggle, 'x' => :execute, 'e' => :edit, 'w' => :write_back, 'r' => :reload, 'd' => :dashboard,
        'p' => :projects, "\e" => :escape, 'q' => :quit
      }.freeze

      module_function

      # A key from getch, which is a string for a printable character and otherwise a number.
      # Letters are the same with Shift, as the buttons show them as capitals.
      def key_event(key)
        key = key.chr if key.is_a?(Integer) && key < 256
        KEYS[key.is_a?(String) ? key.downcase : key]
      end

      # The mouse buttons that click, which are the left button's. Scrolling does nothing, and since older ncurses,
      # like macOS's, has no button for scrolling down, it can't be mistaken for a click.
      CLICKS = Curses::BUTTON1_PRESSED | Curses::BUTTON1_CLICKED

      # A click sends the event of what's under it.
      def mouse_event(event, zones)
        click(zones, column: event.x, row: event.y) if event.bstate.anybits?(CLICKS)
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
