# frozen_string_literal: true

require_relative '../events'
require_relative '../../sketches'

module Raindown
  module TUI
    # The sketches from Claude Code's replies, in the project's .raindown/sketches.md, one at a time, newest first, of the
    # kind they're filtered to. The arrows move between them, and the file's read again when it changes, like when a
    # reply's saved more, showing the newest then. E opens the sketch in the editor.
    # The title above them, the kind they're filtered to, drops down the kinds with Enter or a click, which up and down
    # move between, and Enter or a click chooses, while Esc closes them without choosing.
    class SketchesView
      MOVES = { up: -1, left: -1, down: 1, right: 1 }.freeze

      attr_reader :cursor, :kind, :menu

      def initialize(root:)
        @root = root
        @path = File.join(root, Sketches::FILE)
        @all = []
        @cursor = 0
      end

      def renderer = SketchesRenderer
      def target = self
      def path = nil
      def typing? = false
      def pace(_hovered) = :active

      def status(_navigator)
        [:info, "#{count(@all.length, 'sketch')} from Claude Code, in #{Sketches::FILE}"]
      end

      # Whether there's a file of sketches yet.
      def saved? = File.exist?(@path)

      # Whether the file's changed since it was read, so it's read again on the next tick.
      def changed? = mtime != @read_at

      def load
        @read_at = mtime
        newest = @all.first&.time
        @all = Sketches.read(@root)
        self.cursor = 0 unless @all.first&.time == newest
        self.cursor = @cursor
      end

      # The sketches of the kind they're filtered to, or all of them.
      def sketches = kind ? @all.select { it.kind == kind } : @all

      def selected = sketches[@cursor]

      # The filter's kinds: nil for all of them, then each kind, each with how many sketches it has.
      def kinds = [[nil, @all.length], *Sketches::KINDS.keys.map { |name| [name, @all.count { it.kind == name }] }]

      def cursor=(index)
        @cursor = index.clamp(0, [sketches.length - 1, 0].max)
      end

      # Every key but Tab to the files, or left from the first sketch, while the kinds are closed.
      def next_step?(key) = !%i[tab tick].include?(key) && !(key == :left && @cursor.zero? && !menu)

      def next_step(key)
        return menu_step(key) if menu
        return open_menu if %i[enter kinds].include?(key)
        return choose(key) if key.is_a?(Integer)
        return move(MOVES[key]) if MOVES.key?(key)

        Edit.new(path: @path, line: selected.line) if key == :edit && selected
      end

      private

      def menu_step(key)
        case key
        when :up, :down then @menu = (@menu + MOVES[key]).clamp(0, kinds.length - 1)
        when :enter then choose(@menu)
        when Integer then choose(key)
        when :escape, :kinds then @menu = nil
        end
        nil
      end

      def open_menu
        @menu = kinds.index { it.first == kind } || 0
        nil
      end

      # Filters the sketches to the kind at the index of the filter's kinds, from the newest.
      def choose(index)
        @kind = kinds[index]&.first
        @menu = nil
        self.cursor = 0
        nil
      end

      def move(by)
        self.cursor = @cursor + by
        nil
      end

      def count(number, noun) = "#{number} #{number == 1 ? noun : "#{noun}es"}"

      def mtime = saved? ? File.mtime(@path) : nil
    end
  end
end
