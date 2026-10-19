# frozen_string_literal: true

require 'antlers/api'
require 'nodes/html_node'
require 'nodes/prop_node'
require 'nodes/slot_node'
require_relative '../raindown/fragments'

module Raindown
  # <{ Card name=p.name }>, rendered by Antlers where it is in the template, so its props see loop variables.
  # Its HTML is kept as a fragment, so Commonmarker doesn't read it as Markdown.
  class PropComponentNode < Antlers::PropNode
    def render(**)
      Fragments.add(super)
    end
  end

  # <{ Card: }>...<{ :Card }>, whose slot is its own Markdown, rendered to HTML in its scope first.
  #
  # Markdown children -> rendered to a Markdown string -> Commonmarker -> HTML
  #   -> wrapped as a single Antlers::HTMLNode (replaces @children for the super call)
  #   -> Antlers::SlotNode#render's "without a template" branch -> slot: receives that HTML
  #   -> Card#render(slot:, **props)
  #
  # This only reaches Card#render directly when Card has no class-level template (see SlotNode#render);
  # otherwise Antlers renders Card's own template instead, with this HTML passed to it as the slot_node.
  class SlotComponentNode < Antlers::SlotNode
    def render(current_binding: nil, parent_binding: nil, slot_node: nil, metadata: {})
      markdown = @children.map { |child| child.render(current_binding:, parent_binding:, slot_node:, metadata:) || '' }.join
      children = @children
      @children = [Antlers::HTMLNode.new(html: Raindown.commonmark(markdown))]

      Fragments.add(super)
    ensure
      @children = children if children
    end
  end
end
