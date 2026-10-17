# frozen_string_literal: true

module Raindown
  # Commonmarker gives each heading a unique id within what it renders, but a document's components render
  # on their own, so two can have a heading with the same id. Later ones get -1, -2 and so on, like Commonmarker.
  module HeadingIds
    HEADING = %r{<h([1-6]) id="([^"]*)"(.*?)</h\1>}m

    module_function

    def unique(html)
      seen = Hash.new(0)

      html.gsub(HEADING) do
        level, id, rest = ::Regexp.last_match.captures
        count = seen[id]
        seen[id] += 1
        next ::Regexp.last_match(0) if count.zero?

        unique_id = "#{id}-#{count}"
        "<h#{level} id=\"#{unique_id}\"#{rest.gsub("href=\"##{id}\"", "href=\"##{unique_id}\"")}</h#{level}>"
      end
    end
  end
end
