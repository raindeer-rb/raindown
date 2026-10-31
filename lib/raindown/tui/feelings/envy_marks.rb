# frozen_string_literal: true

require_relative 'kept_log'

module Raindown
  module TUI
    # Which of Code feelings' methods are marked as envious, in their own tint, with why below the grid, and how K keeps
    # the selected one, in the KeptLog, until its code changes.
    module EnvyMarks
      # The method's Envy, when it's envious, and nobody's kept it since its code last changed, or nil.
      def envy(method)
        return unless method&.envy&.envious?
        return if @kept.dismissed?(method)

        method.envy
      end

      private

      # Keeps the selected envious method where it is, until its code changes.
      def kept
        return unless envy(selected)

        @kept.dismiss(selected)
        Kept.new(method: selected)
      end
    end
  end
end
