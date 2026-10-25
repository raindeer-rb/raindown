# frozen_string_literal: true

require 'cgi/escape'

require_relative 'node'

module Raindown
  # The node behind toc: and :toc, a table of contents of the document's headings.
  # A project can replace it with its own TOC node in .raindown, like "class TOC < Raindown::TOC".
  class TOC < Node
    # A heading with an id, in the HTML that Commonmarker and Raindown's components write, like <h2 id="setup">.
    HEADING = %r{<h([1-6])\b[^>]*?\bid=(?:"([^"]*)"|'([^']*)'|([^\s>]+))[^>]*>(.*?)</h\1\s*>}mi
    # Comments and scripts can hold heading tags that aren't in the page.
    IGNORED = %r{<!--.*?-->|<script\b.*?</script\s*>}mi
    TAG = /<[^>]*>/

    def replace(document:, metadata: nil, bare: false)
      headings = headings(markdown: document, metadata:, bare:)
      return '' if headings.empty?

      min_level = headings.map { |heading| heading[:level] }.min

      headings.map do |heading|
        "#{'  ' * (heading[:level] - min_level)}- [#{heading[:text]}](##{heading[:id]})"
      end.join("\n")
    end

    # With the document's final HTML, the headings include ones its components render.
    def render(document:, html: nil, metadata: nil, bare: false)
      items = headings(markdown: document, html:, metadata:, bare:).map do |heading|
        "<li class='h#{heading[:level]}'><a href='##{heading[:id]}'>#{CGI.escapeHTML(heading[:text])}</a></li>"
      end

      <<~HTML
        <div class="floating">
          <details id="toc" open>
            <summary>Table of contents</summary>
            <ul>
              #{items.join("\n")}
            </ul>
          </details>
        </div>
      HTML
    end

    # The document's headings, from its final HTML, or else by rendering it with its components.
    def headings(markdown:, html: nil, metadata: nil, bare: false)
      html ||= Fragments.collect { Raindown.assembled(markdown:, metadata: metadata || NoMetadata, bare:) }

      html.gsub(IGNORED, '').scan(HEADING).map do |level, *ids, content|
        { level: level.to_i, text: CGI.unescapeHTML(content.gsub(TAG, '')).strip, id: CGI.unescapeHTML(ids.compact.first) }
      end
    end
  end
end
