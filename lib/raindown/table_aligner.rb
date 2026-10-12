# frozen_string_literal: true

require 'unicode/display_width'

module Raindown
  # Pads every column of each Markdown table to the width of its widest cell.
  class TableAligner
    DELIMITER_CELL = /\A:?-+:?\z/
    FENCE = /\A\s*(```|~~~)/

    def self.format(content:, **)
      new(content:).format
    end

    def initialize(content:)
      @lines = content.lines
    end

    def format
      output = []
      index = 0
      in_fence = false

      while index < @lines.length
        line = @lines[index]
        in_fence = !in_fence if line.match?(FENCE)

        if !in_fence && table_start?(index)
          table_end = find_table_end(index)
          output.concat(align(@lines[index...table_end]))
          index = table_end
        else
          output << line
          index += 1
        end
      end

      output.join
    end

    private

    def table_start?(index)
      header = @lines[index]
      delimiter = @lines[index + 1]
      return false unless header&.include?('|') && delimiter

      delimiter_cells = cells(delimiter)
      delimiter_cells.any? && delimiter_cells.all? { |cell| cell.match?(DELIMITER_CELL) } &&
        delimiter_cells.length == cells(header).length
    end

    def find_table_end(index)
      table_end = index + 2
      table_end += 1 while @lines[table_end]&.include?('|') && !@lines[table_end].strip.empty?
      table_end
    end

    def align(table)
      indent = table.first[/\A\s*/]
      rows = table.map { |line| cells(line) }
      header, delimiter, *body = rows
      return table if body.any? { |row| row.length > header.length }

      table_lines(indent:, header:, body:, alignments: delimiter.map { |cell| alignment(cell) })
    end

    def table_lines(indent:, header:, body:, alignments:)
      body = body.map { |row| row + ([''] * (header.length - row.length)) }
      widths = column_widths(rows: [header, *body])

      [
        row_line(indent:, cells: header, widths:, alignments:),
        delimiter_line(indent:, widths:, alignments:),
        *body.map { |row| row_line(indent:, cells: row, widths:, alignments:) }
      ].map { |line| "#{line}\n" }
    end

    # Split on pipes that aren't escaped, dropping the optional outer pipes.
    def cells(line)
      content = line.strip
      content = content.delete_prefix('|')
      content = content.delete_suffix('|') unless content.end_with?('\|')

      content.split(/(?<!\\)\|/, -1).map(&:strip)
    end

    def alignment(cell)
      if cell.start_with?(':') && cell.end_with?(':') then :center
      elsif cell.end_with?(':') then :right
      elsif cell.start_with?(':') then :left
      end
    end

    # Three is the shortest delimiter cell, which also fits ':-:'.
    def column_widths(rows:)
      rows.transpose.map { |column| [column.map { |cell| display_width(cell) }.max, 3].max }
    end

    # Wide characters like CJK and emoji take two columns. Emoji are always measured as two,
    # instead of guessing from the terminal, so a file formats the same on every machine.
    def display_width(cell)
      Unicode::DisplayWidth.of(cell, emoji: :all)
    end

    def row_line(indent:, cells:, widths:, alignments:)
      padded = cells.each_with_index.map { |cell, i| pad(cell, widths[i], alignments[i]) }
      "#{indent}| #{padded.join(' | ')} |"
    end

    def delimiter_line(indent:, widths:, alignments:)
      dashes = widths.each_with_index.map do |width, i|
        case alignments[i]
        when :center then ":#{'-' * (width - 2)}:"
        when :right then "#{'-' * (width - 1)}:"
        when :left then ":#{'-' * (width - 1)}"
        else '-' * width
        end
      end

      "#{indent}| #{dashes.join(' | ')} |"
    end

    def pad(cell, width, alignment)
      padding = width - display_width(cell)

      case alignment
      when :center then "#{' ' * (padding / 2)}#{cell}#{' ' * (padding - (padding / 2))}"
      when :right then "#{' ' * padding}#{cell}"
      else "#{cell}#{' ' * padding}"
      end
    end
  end
end
