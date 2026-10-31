# frozen_string_literal: true

require_relative 'content_log'

module Raindown
  module TUI
    # Which of Code feelings' methods are marked as envious, in their own tint, with why below the grid, and how C says
    # the selected one isn't, in the ContentLog, until its code changes.
    module EnvyMarks
      # The method's Envy, when it's envious, and nobody's said it's content since its code last changed, or nil.
      def envy(method)
        return unless method&.envy&.envious?
        return if @contents.dismissed?(method)

        method.envy
      end

      private

      # Says the selected envious method is content, until its code changes.
      def contented
        return unless envy(selected)

        @contents.dismiss(selected)
        Content.new(method: selected)
      end
    end
  end
end
