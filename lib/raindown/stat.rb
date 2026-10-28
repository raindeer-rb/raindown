# frozen_string_literal: true

require_relative 'node'

module Raindown
  # The base of a project's stats: one big number in block digits, above its label, written into the Markdown as code,
  # and shown on the terminal UI's Dashboard as a card, like a chart:
  #    ▀█  ▀▀█
  #     █  █▀▀
  #    ▀▀▀ ▀▀▀
  #   open issues
  # A stat's a node in .raindown that says its value, and its label:
  #   class Issues < Raindown::Stat
  #     def value(metadata:) = Issue.open.count
  #     def label = 'open issues'
  #   end
  class Stat < Node
    # Each character's three lines in block digits, which end on the top half of the third, where a point sits too.
    # Others are left as they are, on the middle line.
    DIGITS = { '0' => ['█▀█', '█ █', '▀▀▀'], '1' => ['▀█ ', ' █ ', '▀▀▀'], '2' => ['▀▀█', '█▀▀', '▀▀▀'],
               '3' => ['▀▀█', ' ▀█', '▀▀▀'], '4' => ['█ █', '▀▀█', '  ▀'], '5' => ['█▀▀', '▀▀█', '▀▀▀'],
               '6' => ['█▀▀', '█▀█', '▀▀▀'], '7' => ['▀▀█', '  █', '  ▀'], '8' => ['█▀█', '█▀█', '▀▀▀'],
               '9' => ['█▀█', '▀▀█', '▀▀▀'], '-' => ['   ', '▀▀▀', '   '], '+' => [' ▄ ', '▀█▀', '   '],
               '.' => [' ', ' ', '▀'], ',' => [' ', ' ', '▀'] }.freeze

    def replace(metadata: NoMetadata) = "```\n#{card_lines(metadata:).join("\n")}\n```"

    # The number in block digits, then the label, as a card on the Dashboard shows them.
    def card_lines(metadata: NoMetadata)
      characters = number(value(metadata:)).chars.map { digit(it) }
      [*Array.new(3) { |line| characters.map { it[line] }.join(' ').rstrip }, label]
    end

    def value(metadata: NoMetadata) = raise(NotImplementedError, "#{self.class} needs a value")

    def label = ''

    # How the value's written, which a stat can change, like with a sign.
    def number(value) = value.to_s

    private

    # The character's three lines in block digits, or itself on the middle line.
    def digit(character) = DIGITS.fetch(character) { [' ', character, ' '] }

    # The project's folder, from the page being rendered, or else the current one.
    def root(metadata)
      return metadata.root if metadata.respond_to?(:root)

      Dir.pwd
    end
  end
end
