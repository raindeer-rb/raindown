# frozen_string_literal: true

require_relative 'calm_log'

module Raindown
  module TUI
    # Which of Code feelings' methods are marked as envious, in their own tint, with why below the grid, and how C calms
    # the selected one, in the CalmLog, until its code changes.
    module EnvyMarks
      # The method's Envy, when it's envious, and nobody's said it's calm since its code last changed, or nil.
      def envy(method)
        return unless method&.envy&.envious?
        return if @calm.dismissed?(method)

        method.envy
      end

      private

      # Says the selected envious method is calm, until its code changes.
      def calmed
        return unless envy(selected)

        @calm.dismiss(selected)
        Calm.new(method: selected)
      end
    end
  end
end
