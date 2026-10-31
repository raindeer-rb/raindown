# frozen_string_literal: true

require_relative 'cuckoos_log'

module Raindown
  module TUI
    # Which of Code feelings' methods are marked as cuckoos, in their own tint, with why below the grid, and how C says
    # the selected one isn't, in the CuckoosLog, until its code changes.
    module CuckooMarks
      # The method's Cuckoo, when it's laid, and nobody's said it isn't one since its code last changed, or nil.
      def cuckoo(method)
        return unless method&.cuckoo&.laid?
        return if @cuckoos.dismissed?(method)

        method.cuckoo
      end

      private

      # Says the selected cuckoo isn't one, until its code changes.
      def not_cuckoo
        return unless cuckoo(selected)

        @cuckoos.dismiss(selected)
        NotCuckoo.new(method: selected)
      end
    end
  end
end
