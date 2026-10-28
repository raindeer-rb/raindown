# frozen_string_literal: true

require_relative 'batch'

module Raindown
  module TUI
    # This week's Batch of a project's code to feel, picked to fill the grid when the view first opens and draws it,
    # then kept through reloads, like after a method's edited or fixed.
    class WeeklyBatch
      attr_reader :batch

      def initialize(log:)
        @log = log
        @batch = Batch.new(files: [], code_methods: [], log:, week: Batch.this_week)
      end

      # The methods read again, keeping the batch's files.
      def read(every)
        @every = every
        @batch = batch.reading(every)
      end

      # Picks the batch to fill the grid's cells, once they're known.
      def fill(grid_cells)
        return if @filled

        @filled = true
        @batch = Batch.pick(@every, log: @log, cells: grid_cells)
      end
    end
  end
end
