# frozen_string_literal: true

require_relative 'batch'

module Raindown
  module TUI
    # This week's batches of a project's code to feel: the current Batch, kept through reloads, picked again to fill
    # the grid the first time it's drawn, and the next one, which skips the current's files until the TUI starts again.
    class Batches
      # The cells a batch fills until the grid's drawn and its own are known.
      GRID_CELLS = 200

      attr_reader :current

      def initialize(log:)
        @log = log
        @current = Batch.new(files: [], code_methods: [], log:, week: Batch.this_week)
        @skipped = Set.new
        @grid_cells = GRID_CELLS
      end

      # The methods read again, keeping the current batch's files, or picking some when it has none.
      def read(every)
        @every = every
        @current = current.reading(every)
        pick if current.code_methods.empty?
      end

      # Picks the batch again to fill the grid's cells, the first time they're known, and whether it did.
      def fill(grid_cells)
        return false if @filled

        @filled = true
        @grid_cells = grid_cells
        pick
        true
      end

      def next
        @skipped.merge(current.files)
        pick
      end

      private

      def pick
        @current = Batch.pick(@every, log: @log, cells: @grid_cells, skipped: @skipped)
      end
    end
  end
end
