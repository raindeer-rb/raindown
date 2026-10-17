# frozen_string_literal: true

require 'antlers/api'
require 'nodes/prop_node'
require 'nodes/slot_node'
require_relative '../raindown/component'

module Raindown
  # <{ Card name=p.name }>, rendered where it is in the template, with the props evaluated in its scope.
  class PropComponentNode < Antlers::PropNode
    def render(current_binding: nil, **)
      props = evaluate_props(props: @props, current_binding:)
      Component.render(klass: class_constant(namespace: @namespace&.split('::') || [], name: @name), props:)
    end
  end

  # <{ Card: }>...<{ :Card }>, whose slot is its own Markdown, rendered to HTML in its scope.
  class SlotComponentNode < Antlers::SlotNode
    def render(current_binding: nil, parent_binding: nil, slot_node: nil, metadata: {})
      markdown = @children.map { |child| child.render(current_binding:, parent_binding:, slot_node:, metadata:) || '' }.join
      props = evaluate_props(props: @props, current_binding:)
      klass = class_constant(namespace: @namespace&.split('::') || [], name:)

      Component.render(klass:, props:, slot: Raindown.commonmark(markdown))
    end
  end
end
