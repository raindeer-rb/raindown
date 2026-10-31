# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'time'

module Raindown
  module TUI
    # The methods everyone's kept where they are, in .raindown/kept.csv with a checksum of their code, like the
    # FeelingsLog, so a method stays dismissed until its code changes, and then it can envy again.
    class KeptLog
      HEADER = %i[timestamp checksum location method].freeze

      def initialize(root:)
        @root = root
        @csv = File.join(root, '.raindown', 'kept.csv')
      end

      # Notes down that the method is kept, in place of anything said about it before.
      def dismiss(method)
        row = { timestamp: Time.now.utc.iso8601, checksum: method.checksum, location: "#{relative(method.path)}:#{method.line}",
                method: method.label }
        write_rows(rows.reject { about?(it, method) } + [row])
      end

      # Whether the method's been kept, by its file, name and code's checksum, wherever its line is now.
      def dismissed?(method) = keys.include?(method_key(method))

      # Forgets the methods that have changed, or gone, since they were dismissed, from the methods there are now.
      def forget_changed(methods)
        now = methods.to_set { method_key(it) }
        current = rows.select { now.include?(key(it)) }
        write_rows(current) unless current.length == rows.length
      end

      # Read once, and again after one's dismissed.
      def rows
        return [] unless File.exist?(@csv)

        @rows ||= CSV.read(@csv, headers: true, header_converters: :symbol).map(&:to_h)
      end

      private

      def keys = @keys ||= rows.to_set { key(it) }

      def about?(row, method) = path(row) == relative(method.path) && row[:method] == method.label

      # The row's file, without the line the method was on.
      def path(row) = row[:location].sub(/:\d+\z/, '')

      # The row's file, method and checksum, to match a method's.
      def key(row) = [path(row), row[:method], row[:checksum]]
      def method_key(method) = [relative(method.path), method.label, method.checksum]

      def write_rows(rows)
        FileUtils.mkdir_p(File.dirname(@csv))
        CSV.open(@csv, 'w') do |csv|
          csv << HEADER
          rows.each { csv << it.values_at(*HEADER) }
        end
        @rows = @keys = nil
      end

      def relative(path) = path.delete_prefix(File.join(@root, ''))
    end
  end
end
