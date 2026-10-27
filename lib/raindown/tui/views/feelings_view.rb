# frozen_string_literal: true

require_relative '../code_methods'
require_relative '../events'
require_relative '../feelings_log'

module Raindown
  module TUI
    # Code feelings, like Severance's macrodata refinement: the project's functions and methods, in any language,
    # as clusters of digits in a grid, where long methods, and ones whose files keep changing, drift. The cursor moves
    # between them, the selected one's code shows below the grid, its first lines or with Enter all that fits, and 1 to 5
    # sort how it feels into a bin: woe, frolic, dread, malice or numb, which notes it down in the FeelingsLog. Frolic and
    # numb move on to the next method, while woe, dread and malice ask why first, typed until Enter, or Esc to leave it
    # out, and stay on it. E opens the method in the editor, and X asks Claude Code to fix it, and either way it's read
    # again after, to be felt again.
    class FeelingsView
      BINS = { bin1: 'woe', bin2: 'frolic', bin3: 'dread', bin4: 'malice', bin5: 'numb' }.freeze
      # The tempers that ask why.
      NOTED = %w[woe dread malice].freeze
      # Its own keys, besides the bins: Enter and Space show all of the selected method's code, or its first lines again.
      KEYS = %i[up down left right edit execute tick enter toggle expand].freeze

      # The temper being noted, and the note typed so far, while it's asking why.
      attr_reader :noting, :note, :code_methods, :cursor, :tick, :log
      # Whether the selected method's code shows all that fits, rather than its first lines, until another's selected.
      attr_reader :expanded

      def initialize(root:)
        @root = root
        @log = FeelingsLog.new(root:)
        @code_methods = []
        @felt = {}
        @cursor = 0
        @tick = 0
        @cells = []
        @columns = 1
      end

      def renderer = FeelingsRenderer
      def target = self
      # It shows Ruby code, which isn't written back.
      def path = nil
      def changed? = false
      def typing? = !noting.nil?
      def status(_navigator) = [:info, "#{code_methods.length} methods to feel in #{File.basename(@root)}"]

      def load
        @code_methods = CodeMethods.list(@root)
        self.cursor = @cursor
      end

      def selected = code_methods[@cursor]

      def cursor=(index)
        index = index.clamp(0, [code_methods.length - 1, 0].max)
        @expanded = false unless index == @cursor
        @cursor = index
      end

      # Each cell's method, by its index, in reading order, in a grid as many cells across as the columns.
      # They're kept, so up and down move a row.
      def cells(columns)
        @columns = columns
        @cells = code_methods.each_with_index.flat_map { |method, index| [index] * method.size }
      end

      # Every key while it's asking why, and otherwise its own, but Tab to the files, or left from the first method.
      def next_step?(key)
        return true if typing?

        (KEYS.include?(key) || BINS.key?(key)) && !(key == :left && @cursor.zero?)
      end

      def next_step(key)
        return note_step(key) if typing?
        return (@tick += 1).then { nil } if key == :tick
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
        when :execute then Fix.new(feeling: @felt[@cursor] || Feeling.new(method: selected, temper: nil, note: nil))
        when :enter, :toggle, :expand then (@expanded = !@expanded).then { nil }
        end
      end

      def move(by)
        self.cursor = @cursor + by
        nil
      end

      # To the method in the cell above or below the selected one's first cell.
      def move_row(by)
        cell = @cells[@cells.index(@cursor).to_i + (by * @columns)]
        self.cursor = cell if cell
        nil
      end

      # Frolic and numb are noted down straight away, moving on to the next method, while the rest ask why first.
      def feel(temper)
        return note_down(temper, nil).tap { move(1) } unless NOTED.include?(temper)

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

      # Notes the feeling down, staying on the method, so it can be fixed with what was just said about it.
      def note_down(temper, note)
        feeling = Feeling.new(method: selected, temper:, note:)
        @felt[@cursor] = feeling
        @noting = nil
        @log.add(feeling)
        Felt.new(feeling:, page: @log.page)
      end
    end
  end
end
