# frozen_string_literal: true

require_relative 'fragments'

module Raindown
  # Components, like <{ Card name=p.name }> or <{ Card: }>...<{ :Card }>, render in the template pass,
  # so their props see loop variables. A slot's Markdown is already HTML by the time the component gets it.
  # The component's HTML is kept as a fragment, so Commonmarker doesn't read it as Markdown.
  module Component
    module_function

    # Creates the component with the props its initialize takes, and renders it with the props and slot render takes.
    def render(klass:, props:, slot: nil)
      instance = klass.new(**accepted(klass.instance_method(:initialize), props))
      Fragments.add(instance.public_send(:render, **accepted(instance.method(:render), props.merge(slot:))).to_s)
    end

    def accepted(method, keywords)
      parameters = method.parameters
      return keywords if parameters.any? { |type, _| type == :keyrest }

      keys = parameters.filter_map { |type, key| key if %i[key keyreq].include?(type) }
      keywords.slice(*keys)
    end
  end
end
