# frozen_string_literal: true

require_relative '../document'
require_relative 'row'

module Raindown
  module TUI
    # The outline pane: a file's headings and directives, read from its Document. Headings fold the section below them,
    # and a directive's output, the lines Raindown wrote back, expands below it. Both start folded away.
    class Outline
      attr_reader :path, :error

      def initialize(path)
        @path = path
        @folded = Set.new
        @expanded = Set.new
        read
      end

      # Reads the file again, keeping what's folded.
      def read
        @mtime = File.mtime(path)
        @document = Document.read(path)
        @lines = File.readlines(path, chomp: true)
        @document.directives # Finds an error in the file, like a missing end tag, now rather than while drawing.
        @error = nil
      rescue StandardError => e
        @error = e.message
      end

      def changed?
        File.exist?(path) && File.mtime(path) != @mtime
      end

      def fold(heading)
        @folded.delete?(heading.line) || @folded.add(heading.line)
      end

      def expand(directive)
        @expanded.delete?(directive.line) || @expanded.add(directive.line)
      end

      def rows
        return [Row.new(text: error, depth: 0, kind: :error, target: 1)] if error

        sections.flat_map do |heading, items|
          next items.flat_map { directive_rows(it, depth: 0) } unless heading

          depth = heading.level - min_level + 1
          [heading_row(heading), *(items.flat_map { directive_rows(it, depth:) } unless @folded.include?(heading.line))]
        end
      end

      private

      # Each heading with the directives below it, leaving out the headings in a folded heading's section.
      # Directives before the first heading come first, with no heading.
      def sections
        sections = [[nil, []]]
        hidden = nil

        items.each do |item|
          heading = item.is_a?(Document::Heading)
          next if hidden && !(heading && item.level <= hidden)

          hidden = (item.level if @folded.include?(item.line)) if heading
          heading ? sections << [item, []] : sections.last.last << item
        end

        sections
      end

      # Headings a directive wrote are part of its output, so they show when it's expanded rather than on their own.
      def items
        outputs = @document.directives.filter_map(&:output)
        @document.outline.reject { |item| item.is_a?(Document::Heading) && outputs.any? { it.cover?(item.line) } }
      end

      def min_level
        @document.headings.map(&:level).min || 1
      end

      def heading_row(heading)
        folded = @folded.include?(heading.line) ? ' …' : ''
        Row.new(text: "#{'#' * heading.level} #{heading.text}#{folded}", depth: heading.level - min_level, kind: :heading,
                target: heading)
      end

      def directive_rows(directive, depth:)
        expanded = @expanded.include?(directive.line)
        row = Row.new(text: directive_text(directive), depth:, kind: :directive, target: directive,
                      buttons: buttons(directive, expanded:))
        return [row] unless expanded

        [row, *directive.output.map do |number|
          Row.new(text: @lines[number - 1].to_s, depth: depth + 1, kind: :output, target: number)
        end]
      end

      def buttons(directive, expanded:)
        buttons = []
        buttons << [expanded ? '[-]' : "[+#{directive.output.size}]", :toggle] if directive.output
        buttons << ['[Run]', :execute] if directive.endpoint?
        buttons
      end

      def directive_text(directive)
        return ":#{directive.name}" unless directive.writes

        [directive.name, ':', (" #{directive.args}" unless directive.args.empty?)].join
      end
    end
  end
end
