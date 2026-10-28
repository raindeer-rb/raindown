# frozen_string_literal: true

require_relative '../events'
require_relative 'cell_moves'
require_relative 'celebration'
require_relative 'code_methods'
require_relative 'feelings_log'
require_relative 'weekly_batch'

module Raindown
  module TUI
    # Code feelings, like Severance's macrodata refinement: the project's functions and methods, in any language,
    # as clusters of digits in a grid, where long methods, and ones whose files keep changing, drift. The cursor moves
    # between them, the selected one's code shows below the grid, its first lines or with Enter all that fits, and 1 to 6
    # sort how it feels into a bin: frolic, hope, numb, woe, dread or malice, which notes it down in the FeelingsLog,
    # staying on it. Woe, dread and malice ask why first, typed until Enter, or Esc to leave it out. E opens the method in the
    # editor, and X asks Claude Code to fix it, and either way it's read again after, to be felt again.
    class FeelingsView
      include CellMoves

      # Best to worst, as CodeHealth scores them, so the keys rate the code.
      BINS = { bin1: 'frolic', bin2: 'hope', bin3: 'numb', bin4: 'woe', bin5: 'dread', bin6: 'malice' }.freeze
      # The tempers that ask why.
      NOTED = %w[woe dread malice].freeze
      # Its own keys, besides the bins: Enter and Space show all of the selected method's code, or its first lines again.
      # Ctrl+T celebrates, to try the rain and the waffle, and isn't shown with the buttons.
      KEYS = %i[up down left right edit execute enter toggle expand celebrate].freeze

      # The temper being noted, and the note typed so far, while it's asking why, whether the selected method's code
      # shows all that fits, until another's selected, and the rain then the waffle, once the batch is refined.
      attr_reader :noting, :note, :cursor, :log, :expanded, :celebration

      def initialize(root:)
        @root = root
        @log = FeelingsLog.new(root:)
        @last_feelings = {}
        @cursor = 0
        @week = WeeklyBatch.new(log: @log)
      end

      def renderer = FeelingsRenderer
      def target = self
      # It shows Ruby code, which isn't written back.
      def path = nil
      def changed? = false
      def typing? = !noting.nil?

      # As fast as an animation while it rains, and otherwise in motion, so its digits tremble at the same pace whether it's
      # used with the keys or the mouse.
      def pace(_hovered)
        return :animation if celebration&.raining?

        :motion
      end

      def status(_navigator) = [:info, "This week's code to feel, #{batch.week}"]

      # Reads the code again, keeping the batch, like after a method's edited or fixed, and the selected method, by its
      # file and name, even when the methods around it change, moving the feelings about code that's changed, or gone, to
      # the memories.
      def load
        was = selected
        every = CodeMethods.list(@root)
        @log.move_stale_to_memories(every)
        @week.read(every)
        self.cursor = code_methods.index { [it.path, it.label] == [was&.path, was&.label] } || @cursor
      end

      # The Batch of files whose methods are in the grid.
      def batch = @week.batch
      def code_methods = batch.code_methods

      def selected = code_methods[@cursor]

      def cursor=(index)
        index = index.clamp(0, [code_methods.length - 1, 0].max)
        @expanded = false unless index == @cursor
        @cursor = index
      end

      # Every key while it's asking why or celebrating, and otherwise its own, but Tab to the files, or left from the
      # first method.
      def next_step?(key)
        return true if typing? || celebration

        (KEYS.include?(key) || BINS.key?(key)) && !(key == :left && @cursor.zero?)
      end

      def next_step(key)
        return note_step(key) if typing?
        return @celebration = nil if celebration&.over?(key)
        return (@celebration = Celebration.new).then { nil } if key == :celebrate
        return unless selected
        return feel(BINS[key]) if BINS.key?(key)

        method_step(key)
      end

      private

      # Moves between the methods, or acts on the selected one.
      def method_step(key)
        case key
        when :left then move(-1)
        when :right then move(1)
        when :up then move_row(-1)
        when :down then move_row(1)
        when :edit then Edit.new(path: selected.path, line: selected.line)
        when :execute then fix
        when :enter, :toggle, :expand then (@expanded = !@expanded).then { nil }
        end
      end

      # Asks to fix the method, with how it last felt, by its file and name, which stay the same when its lines change.
      def fix = Fix.new(feeling: @last_feelings[[selected.path, selected.label]] || Feeling.new(method: selected, temper: nil, note: nil))

      # Frolic and numb are noted down straight away, while the rest ask why first.
      def feel(temper)
        return note_down(temper, nil) unless NOTED.include?(temper)

        @noting = temper
        @note = +''
        nil
      end

      def note_step(key)
        case key
        when Type then @note << key.text
        when :backspace then @note.chop!
        when :enter then return note_down(@noting, (@note unless @note.strip.empty?))
        when :escape then return note_down(@noting, nil)
        end
        nil
      end

      # Notes the feeling down, staying on the method, so it can be fixed with what was just said about it. It rains
      # when that refines the batch.
      def note_down(temper, note)
        feeling = Feeling.new(method: selected, temper:, note:)
        @last_feelings[[selected.path, selected.label]] = feeling
        @noting = nil
        refined = batch.refined?
        @log.add(feeling)
        @celebration = Celebration.new if !refined && batch.refined?
        Felt.new(feeling:)
      end
    end
  end
end
