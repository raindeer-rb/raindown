# frozen_string_literal: true

require 'csv'
require 'json'
require 'yaml'

require_relative '../node'

module Raindown
  class Chart < Node
    class Error < StandardError; end

    # A chart's data as points, each value with its label, or with nil for numbers alone.
    # Label and value are the columns to chart, by name or index, which default to the first column
    # and the first column of numbers after it. Rows without a number are left out.
    class Points
      NUMBER = /\A[+-]?(?:\d{1,3}(?:,\d{3})+|\d+)?(?:\.\d+)?\z/

      def initialize(label: nil, value: nil, root: Dir.pwd)
        @label = label
        @value = value
        @root = root
      end

      def from(data)
        case data
        when String then from_string(data)
        when Numeric then [[nil, data]]
        when Hash then from_table(data.to_a, header: false)
        when Array then from_list(data)
        else raise Error, 'there is no data'
        end
      end

      private

      # A file's path, relative to the root, or numbers like '3 5 -2 8' or '3, 5, -2, 8'.
      def from_string(string)
        numbers = string.strip.split(/[\s,]+/)
        return numbers.map { [nil, number(it)] } if numbers.any? && numbers.all? { number(it) }

        path = File.expand_path(string, @root)
        raise Error, 'no such file' unless File.file?(path)

        from(read(path))
      end

      def read(path)
        text = File.read(path, encoding: Encoding::UTF_8)

        case File.extname(path).downcase
        when '.csv' then CSV.parse(text, skip_blanks: true)
        when '.tsv' then CSV.parse(text, col_sep: "\t", skip_blanks: true)
        when '.json' then JSON.parse(text)
        when '.yml', '.yaml' then YAML.safe_load(text)
        else raise Error, 'only CSV, TSV, JSON and YAML files can be charted'
        end
      rescue CSV::MalformedCSVError, JSON::ParserError, Psych::SyntaxError => e
        raise Error, e.message
      end

      # Numbers, rows of hashes like JSON or YAML, or rows of cells like CSV.
      def from_list(list)
        return list.map { [nil, number(it)] } if list.all? { number(it) }
        return from_table(hash_rows(list), header: true) if list.all?(Hash)
        return from_table(list, header: header?(list.first)) if list.all?(Array)

        raise Error, 'it needs numbers, or rows with a number in each'
      end

      # Rows of hashes as a table, with their keys as its header.
      def hash_rows(rows)
        keys = rows.flat_map(&:keys).uniq
        [keys.map(&:to_s), *rows.map { |row| row.values_at(*keys) }]
      end

      # A first row without numbers names the columns, like "month,downloads".
      def header?(row)
        row.none? { number(it) }
      end

      def from_table(rows, header:)
        names = header ? rows.first.map(&:to_s) : []
        rows = rows.drop(1) if header
        label, value = columns(rows, names)

        rows.filter_map do |row|
          number = number(row[value])
          [label && row[label].to_s, number] if number
        end
      end

      # The label and value columns' indexes, where a single column of numbers has no labels.
      def columns(rows, names)
        count = rows.map(&:length).max.to_i
        label = column(@label, names) if @label
        value = column(@value, names) if @value
        label ||= (0...count).find { it != value } if count > 1
        value ||= (0...count).find { |index| index != label && rows.any? { number(it[index]) } }
        raise Error, 'there is no column of numbers' unless value

        [label, value]
      end

      def column(name, names)
        return name if name.is_a?(Integer)

        names.index(name.to_s) || raise(Error, "there is no #{name.inspect} column")
      end

      def number(value)
        return value if value.is_a?(Numeric)
        return unless value.is_a?(String) && value.strip.match?(NUMBER) && value.match?(/\d/)

        text = value.strip.delete(',')
        text.include?('.') ? Float(text) : Integer(text, 10)
      end
    end
  end
end
