# frozen_string_literal: true

require 'erb'
require 'nokogiri'

require_relative 'node'

module Raindown
  # The node behind toc: and :toc, a table of contents of the document's headings.
  # A project can replace it with its own TOC node in .raindown, like "class TOC < Raindown::TOC".
  class TOC < Node
    def replace(document:, metadata: nil, bare: false)
      headings = headings(markdown: document, metadata:, bare:)
      return '' if headings.empty?

      min_level = headings.map { |heading| heading[:level] }.min

      headings.map do |heading|
        "#{'  ' * (heading[:level] - min_level)}- [#{heading[:text]}](##{heading[:id]})"
      end.join("\n")
    end

    def render(document:, metadata: nil, bare: false)
      items = headings(markdown: document, metadata:, bare:).map do |heading|
        "<li class='h#{heading[:level]}'><a href='##{heading[:id]}'>#{ERB::Util.html_escape(heading[:text])}</a></li>"
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

    private

    def headings(markdown:, metadata: nil, bare: false)
      html = Raindown.html(markdown:, variables: variables(markdown:), metadata:, bare:)

      Nokogiri::HTML(html).css(HEADINGS).map do |heading|
        { level: heading.name[1].to_i, text: heading.text.strip, id: heading['id'] }
      end
    end
  end
end
