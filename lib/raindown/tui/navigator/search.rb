# frozen_string_literal: true

require_relative '../events'
require_relative '../views/endpoint_view'
require_relative '../workers/worker'

module Raindown
  module TUI
    # Teleport: "/" opens a search of the Dashboard, Code feelings, every file, heading and directive in the files, and every endpoint,
    # matched as it's typed by letters in order, so "stp" finds "## Setup". Up and down move between the matches,
    # Enter or a click opens the one selected, and Esc closes it. Other keys and clicks do nothing while it's open.
    module Search
      # The most matches it shows.
      LIMIT = 10

      # A place to teleport to: its text, where it is, like "guides/setup.md:12", and the step that opens it.
      Place = Data.define(:text, :where, :open) do
        # How well the query matches, or nil when it doesn't: in the text alone, which ranks above a match that needs
        # where it is too, like "setup notes" for "## Setup" in notes.md.
        def score(query)
          in_text = letters_score(text, query)
          return in_text + query.length if in_text

          letters_score("#{text} #{where}", query)
        end

        private

        # How well the query's letters appear in order in the text, ignoring case: higher for runs of them and for
        # the starts of words, or nil when they don't all appear.
        def letters_score(text, query)
          haystack = text.downcase
          last = -1
          score = 0
          query.downcase.each_char do |char|
            index = haystack.index(char, last + 1)
            return nil unless index

            score += 1
            score += 2 if index == last + 1
            score += 2 if index.zero? || haystack[index - 1].match?(%r{[\s/#:._-]})
            last = index
          end
          score
        end
      end

      # What's typed, while the search is open, and the selected match.
      attr_reader :query, :match

      def searching? = !query.nil?

      # The places that match what's typed, best first, then in the order they're in the files.
      def matches
        @places.each_with_index.filter_map { |place, index| (score = place.score(query)) && [-score, index, place] }
               .min(LIMIT).map(&:last)
      end

      private

      def open_search
        @places = places
        @match = 0
        @query = ''
        nil
      end

      def search_event(name)
        case name
        when :up, :down then move_match(name == :up ? -1 : 1)
        when :enter then teleport
        when :escape then close_search
        when :backspace then type_query(query[0...-1])
        end
      end

      def type_query(query)
        @query = query
        @match = 0
        nil
      end

      def move_match(by)
        @match = (@match + by).clamp(0, [matches.length - 1, 0].max)
        nil
      end

      def teleport
        place = matches[@match]
        close_search
        place&.open&.take(self)
      end

      def close_search
        @query = nil
        nil
      end

      def places
        [Place.new(text: 'Dashboard', where: '', open: OpenView.new(view: dashboard)),
         Place.new(text: 'Code feelings', where: '', open: OpenView.new(view: feelings)),
         *@files.files.flat_map { file_places(it) },
         *@endpoints.all.map { Place.new(text: it.text, where: "#{relative(it.path)}:#{it.line}", open: open_endpoint(it)) }]
      end

      # The file, then its headings and directives, in the order they're in it.
      def file_places(path)
        outline = @workers.for(path).call(:outline, path)
        where = relative(path)
        items = (outline.headings + outline.directives).sort_by(&:line)
        [Place.new(text: where, where: '', open: Open.new(path:, line: nil)),
         *items.map { Place.new(text: item_text(it), where: "#{where}:#{it.line}", open: Open.new(path:, line: it.line)) }]
      rescue Worker::Error
        []
      end

      def item_text(item)
        return "#{'#' * item.level} #{item.text}" if item.is_a?(Document::Heading)

        "#{item.name}: #{item.args}".strip
      end

      def open_endpoint(endpoint) = OpenView.new(view: EndpointView.new(endpoint, workers: @workers))
    end
  end
end
