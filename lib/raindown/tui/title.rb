# frozen_string_literal: true

module Raindown
  module TUI
    # A Layout's title line: Raindown's name, the folder the files are shown from, and the page.
    module Title
      # The rain cloud without the emoji variation selector, like the nav's projects, which terminals draw one column wide,
      # as it's measured, so the title line reaches the edge.
      NAME = '🌧  Raindown'

      private

      # The name, the folder, which opens the project menu when there's more than one project, and the page.
      def title
        parts = [[name, nil], ["#{location}#{' ▾' if navigator.projects?}", (:projects if navigator.projects?)],
                 [" › #{view_renderer.page}", nil]]

        parts.zip(spread(parts.map(&:first), width)).map do |(text, event), part_width|
          segment(text, :title, width: part_width, event:)
        end
      end

      def name = " #{NAME}  "

      # The folder the files are shown from.
      def location = from_home(navigator.base)
    end
  end
end
