# frozen_string_literal: true

module Raindown
  # The HTML of components rendered while a document renders, kept out of its Markdown as placeholders
  # so Commonmarker doesn't read it as Markdown, then filled in once the document is HTML.
  module Fragments
    PLACEHOLDER = /<!-- raindown:fragment (\d+) -->/

    module_function

    # Collects the fragments added while the block runs, like one document's render.
    def collect
      outer = Thread.current[:raindown_fragments]
      Thread.current[:raindown_fragments] = []
      yield
    ensure
      Thread.current[:raindown_fragments] = outer
    end

    def add(html)
      list << html
      "<!-- raindown:fragment #{list.length - 1} -->"
    end

    # Fills each placeholder, again and again, since a fragment can hold others, like a component in a slot.
    def fill(html)
      html = html.gsub(PLACEHOLDER) { list[::Regexp.last_match(1).to_i] } while html.match?(PLACEHOLDER)
      html
    end

    def list
      Thread.current[:raindown_fragments] ||= []
    end
  end
end
