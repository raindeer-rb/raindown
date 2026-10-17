# frozen_string_literal: true

# A component for the render tree specs, which takes its props and slot as keywords.
class SpecCard
  def initialize(name: nil)
    @name = name
  end

  def render(slot: nil)
    %(<section data-name="#{@name}">#{slot}</section>\n)
  end
end
