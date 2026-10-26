# frozen_string_literal: true

module Raindown
  module TUI
    # A Layout's title line: Raindown's name, the folder the files are shown from, and the page.
    module Title
      # Terminals draw the rain cloud one column wide or two, so the title line stops a column short of the edge,
      # and doesn't wrap when it's drawn wider than it's measured.
      NAME = '🌧️ Raindown'

      private

      # The name, the folder, which opens the project menu when there's more than one project, and the page.
      def title
        parts = [[name, nil], ["#{location}#{' ▾' if navigator.projects?}", (:projects if navigator.projects?)],
                 [" › #{page}", nil]]

        parts.zip(spread(parts.map(&:first), width - 1)).map do |(text, event), part_width|
          segment(text, :title, width: part_width, event:)
        end
      end

      def name = " #{NAME}  "

      def page
        if dashboard? then 'Dashboard'
        elsif navigator.view == :endpoint then navigator.endpoint_view.endpoint.text
        elsif navigator.path then navigator.relative(navigator.path)
        else 'No Markdown files'
        end
      end

      # The folder the files are shown from, from the home folder when it's in it, like ~/dev/raindown.
      def location = from_home(navigator.base)

      def from_home(path)
        home = Dir.home
        path == home || path.start_with?(File.join(home, '')) ? path.sub(home, '~') : path
      rescue ArgumentError
        path
      end
    end
  end
end
