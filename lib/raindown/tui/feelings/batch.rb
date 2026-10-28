# frozen_string_literal: true

require 'date'
require 'zlib'

module Raindown
  module TUI
    # Files to feel, like the files Severance's refiners work through: the first in the week's shuffled order, as many as
    # fill the grid's cells, with their methods shuffled together. The order is random, but the same all week, so the
    # grid stays put through reloads, edits and restarts, and once it's refined, that's the week's work done.
    Batch = Data.define(:files, :code_methods, :log, :week) do
      # Like 2026-W44, from the ISO year and week.
      def self.this_week(date = Date.today) = "#{date.cwyear}-W#{date.cweek}"

      def self.pick(every, log:, cells:, week: this_week)
        files = filling(every.group_by(&:path).sort_by { |path, _| Zlib.crc32("#{week}:#{path}") }, cells)

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
        "#{code_methods.count { felt?(it) } * 100 / [code_methods.length, 1].max}% refined"
      end
    end
  end
end
