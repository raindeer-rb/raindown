# frozen_string_literal: true

module Raindown
  # The front matter values that Antlers variables like {title} and <{ title }> render.
  # Antlers reads a variable from the binding's locals, then by sending it to the binding's receiver, which is this.
  # It's a BasicObject so a key like "hash" or "display" isn't shadowed by a method, and unknown names render nothing.
  # Nested values work too, like {author.name} and <{ for: tag in tags }>.
  class Variables < BasicObject
    def self.wrap(value)
      case value
      when ::Hash then new(value)
      when ::Array then value.map { |item| wrap(item) }
      else value
      end
    end

    def initialize(values)
      @values = values.to_h { |key, value| [key.to_sym, Variables.wrap(value)] }
    end

    def respond_to?(name, _include_all = false) # rubocop:disable Style/OptionalBooleanParameter -- Ruby's signature
      @values.key?(name.to_sym)
    end

    def send(name, *)
      @values[name.to_sym]
    end

    def binding
      ::Kernel.binding
    end

    def to_s
      @values.to_s
    end
    alias inspect to_s

    def method_missing(*)
      nil
    end

    def respond_to_missing?(*)
      false
    end
  end
end
