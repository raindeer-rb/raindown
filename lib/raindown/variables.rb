# frozen_string_literal: true

module Raindown
  # The front matter values that Antlers variables like {title} and <{ title }> render.
  # Antlers reads a variable from the binding's locals, then by sending it to the binding's receiver, which is this.
  # It's a BasicObject so a key like "hash" or "display" isn't shadowed by a method, and unknown names render nothing.
  # Nested values work too, like {author.name} and <{ for: tag in: tags }>.
  class Variables < BasicObject
    # Braces in a value become the placeholders that render as braces, so Antlers doesn't read them as a variable.
    def self.wrap(value)
      case value
      when ::Hash then new(value)
      when ::Array then value.map { |item| wrap(item) }
      when ::String then value.gsub(/[{}]/, CODE_BRACES)
      else value
      end
    end

    # A wrapped value as the data it was, so a variable in a node's props is a hash, list or text like any other.
    def self.unwrap(value)
      case value
      when Variables then value.to_h
      when ::Array then value.map { |item| unwrap(item) }
      when ::String then value.tr(CODE_BRACES.values.join, CODE_BRACES.keys.join)
      else value
      end
    end

    # A variable's value, like author.name, read the way {author.name} reads it, unwrapped. Unknown names are nil.
    def self.value(variables, name)
      unwrap(name.split('.').reduce(variables) { |value, key| value.respond_to?(key) ? value.send(key) : nil })
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

    def to_h
      @values.transform_values { |value| Variables.unwrap(value) }
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
