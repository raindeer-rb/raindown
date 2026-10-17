# frozen_string_literal: true

require 'erb'

module Raindown
  # Content directives, like a node's directive and end tag or an endpoint's, are kept in the HTML:
  # in bold by default, or as HTML comments with the hide_directives setting.
  # Until then each is a comment marker, which ends the Markdown block before it and starts nothing itself,
  # so a node's list stays its own list.
  # Template directives, like for: and if:, are always invisible, since they often sit inside tables and lists.
  module Directives
    MARKER = /<!-- raindown:directive (.*?) -->/

    module_function

    # A directive like "files: folder: 'notes'", or a whole line like <{ :files }>, as a marker.
    def marker(directive)
      text = directive.strip.delete_prefix('<{').delete_suffix('}>').strip.gsub('--', '- -')
      "<!-- raindown:directive #{text} -->"
    end

    def render(html, hide: false)
      html.gsub(MARKER) do
        text = ::Regexp.last_match(1)
        hide ? "<!-- #{text} -->" : "<p><strong>#{ERB::Util.html_escape(text)}</strong></p>"
      end
    end
  end
end
