# frozen_string_literal: true

require_relative 'batch'

module Raindown
  module TUI
    # This week's Batch of a project's code to feel, picked to fill the grid when the view first opens and draws it,
    # then kept through reloads, like after a method's edited or fixed, until the screen's resized.
    class WeeklyBatch
      # How long a resized grid keeps its new number of cells before the batch is picked again to fill it, so it isn't
      # picked for every size the screen passes through while it's dragged.
      RESIZE_SECONDS = 2

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

      # Picks the batch to fill the grid's cells, once they're known, and again once a resized grid's kept its new number
      # of them for RESIZE_SECONDS, and returns whether it did.
      def fill(grid_cells, now: Process.clock_gettime(Process::CLOCK_MONOTONIC))
        return refill(grid_cells) unless @filled_for

        @resizing = nil unless @resizing&.first == grid_cells
        return false if grid_cells == @filled_for

        @resizing ||= [grid_cells, now]
        return false if now - @resizing.last < RESIZE_SECONDS

        refill(grid_cells)
      end

      private

      def refill(grid_cells)
        @filled_for = grid_cells
        @resizing = nil
        @batch = Batch.pick(@every, log: @log, cells: grid_cells)
        true
      end
    end
  end
end
