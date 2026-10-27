# frozen_string_literal: true

require 'date'
require 'zlib'

module Raindown
  module TUI
    # Files to feel, like the files Severance's refiners work through: as many as fill the grid's cells, picked in the
    # week's shuffled order from those with methods left to feel, apart from any skipped, with their methods shuffled
    # together. The order is random, but the same all week, so the grid stays put through reloads and edits.
    Batch = Data.define(:files, :code_methods, :log, :week) do
      # Like 2026-W44, from the ISO year and week.
      def self.this_week(date = Date.today) = "#{date.cwyear}-W#{date.cweek}"

      def self.pick(every, log:, cells:, skipped: Set.new, week: this_week)
        methods = every.group_by(&:path).reject { |path, file| skipped.include?(path) || file.all? { log.felt?(it) } }
        methods = every.group_by(&:path) if methods.empty?
        files = filling(methods.sort_by { |path, _| Zlib.crc32("#{week}:#{path}") }, cells)

        new(files:, code_methods: [], log:, week:).reading(every)
      end

      # The files, in order, whose methods' cells fit in the grid's, passing over any too big for what's left, and
      # at least the first.
      def self.filling(files, cells)
        used = 0
        files.each_with_object([]) do |(path, methods), picked|
          size = methods.sum(&:size)
          next unless picked.empty? || used + size <= cells

          picked << path
          used += size
        end
      end

      # The same files, with their methods read again, like after one's edited.
      def reading(every)
        with(code_methods: every.select { files.include?(it.path) }.sort_by { Zlib.crc32("#{week}:#{it.path}:#{it.label}") })
      end

      def felt?(method) = log.felt?(method)
      def refined? = code_methods.all? { felt?(it) }

      def progress
        return '100% refined · N for the next files' if refined?

        "#{code_methods.count { felt?(it) } * 100 / [code_methods.length, 1].max}% refined"
      end
    end
  end
end
