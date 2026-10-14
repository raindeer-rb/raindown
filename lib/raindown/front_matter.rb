# frozen_string_literal: true

require 'date'
require 'yaml'

module Raindown
  # YAML between two --- lines at the very start of a file.
  module FrontMatter
    PATTERN = /\A---[ \t]*\r?\n(.*?)^---[ \t]*(?:\r?\n|\z)/m

    module_function

    # Returns the metadata and the Markdown after it.
    def parse(content)
      match = content.match(PATTERN)
      return [{}, content] if match.nil?

      metadata = YAML.safe_load(match[1], permitted_classes: [Date, Time], symbolize_names: true)
      [metadata.is_a?(Hash) ? metadata : {}, match.post_match]
    end

    # How many of the lines are front matter, so directives in its YAML are left alone.
    def line_count(lines)
      lines.join.match(PATTERN)&.then { |match| match[0].lines.length } || 0
    end
  end
end
