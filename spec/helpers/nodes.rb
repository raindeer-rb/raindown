# frozen_string_literal: true

require 'raindown/node'

# Nodes for the node specs. Real projects keep theirs in a .raindown folder, as LowNodes.
class SpecReleases < Raindown::Node
  RELEASES = [%w[1.2.0 Bare], %w[1.1.0 Fetched], %w[1.0.0 First]].freeze

  def initialize(limit: 5)
    @releases = RELEASES.first(limit)
    @count = 0
  end

  def replace
    @releases.map { |version, summary| "- **#{version}** #{summary}" }.join("\n")
  end

  # Counts its renders, to show the same instance renders each time.
  def render
    @count += 1
    "<ol data-count=\"#{@count}\">#{@releases.map { |version, _| "<li>#{version}</li>" }.join}</ol>"
  end
end

# A node with no HTML of its own, so its Markdown renders.
class SpecHeading < Raindown::Node
  def initialize(title: 'Untitled')
    @title = title
  end

  def replace
    "## #{@title}"
  end
end

# A node that writes two paragraphs, which only fit in a delimited block.
class SpecParagraphs < Raindown::Node
  def replace
    "One.\n\nTwo."
  end
end
