# frozen_string_literal: true

require 'csv'
require 'date'
require 'fileutils'
require 'open3'

module Raindown
  module TUI
    # How a method felt: one of Severance's four tempers, woe, frolic, dread or malice, or numb, with an optional note.
    Feeling = Data.define(:method, :temper, :note) do
      # What Claude Code is asked, to fix the method.
      def prompt
        "Refactor #{method.label} in #{method.path}:#{method.line}. #{felt} " \
          "Keep its behaviour, follow the project's CLAUDE.md if it has one, and run the specs."
      end

      def felt
        return 'It needs a second look.' unless temper

        "It felt like #{temper}#{": #{note}" if note}."
      end
    end

    # The feelings everyone's sorted about the code as it is now, kept in .raindown/feelings.csv with the commit they were
    # felt at, which a node can count, like the README's code debt. A feeling about code that's since changed, or gone, moves to
    # .raindown/memories.csv, so the feelings stay few, and the history's kept.
    class FeelingsLog
      TEMPERS = %w[frolic hope numb woe dread malice].freeze
      HEADER = %i[when where method temper note commit checksum].freeze
      def initialize(root:)
        @root = root
        @csv = File.join(root, '.raindown', 'feelings.csv')
        @memories = File.join(root, '.raindown', 'memories.csv')
      end

      # Adds the feeling, as the newest, in place of one about the method before, which moves to the memories if it was
      # about the method's code before it changed.
      def add(feeling)
        method = feeling.method
        row = {
          when: Date.today.iso8601,
          where: where(method),
          method: method.label,
          temper: feeling.temper,
          note: feeling.note,
          commit:,
          checksum: method.checksum
        }
        changed, others = rows.reject { felt_row?(it, method) }.partition { about?(it, method) }
        append_memories(changed)
        write_rows(others + [row])
      end

      # Moves the feelings about methods that have changed, or gone, since they were felt, from the methods there are
      # now, to the memories.
      def move_stale_to_memories(methods)
        now = methods.to_set { method_key(it) }
        stale, current = rows.partition { !now.include?(key(it)) }
        return if stale.empty?

        append_memories(stale)
        write_rows(current)
      end

      # Read once, and again after a feeling's added.
      def rows
        return [] unless File.exist?(@csv)

        @rows ||= CSV.read(@csv, headers: true, header_converters: :symbol).map(&:to_h)
      end

      # Whether the method's been felt, by its file, name and code's checksum, wherever its line is now. The answer's kept
      # until a feeling's added.
      def felt?(method)
        @felt ||= rows.to_set { key(it) }
        @felt_methods ||= {}
        @felt_methods.fetch(method) { @felt_methods[method] = @felt.include?(method_key(method)) }
      end

      # How the method last felt, while its code's the same as when it was felt, or nil.
      def temper(method) = rows.reverse.find { felt_row?(it, method) }&.fetch(:temper)

      # How many feelings there are of each temper, in the bins' order.
      def counts
        tally = rows.map { it[:temper] }.tally
        TEMPERS.to_h { [it, tally.fetch(it, 0)] }
      end

      private

      def felt_row?(row, method) = key(row) == method_key(method)

      def about?(row, method) = path(row) == relative(method.path) && row[:method] == method.label

      # The row's file, without the line the method was on.
      def path(row) = row[:where].sub(/:\d+\z/, '')

      # The row's file, method and checksum, to match a method's.
      def key(row) = [path(row), row[:method], row[:checksum]]
      def method_key(method) = [relative(method.path), method.label, method.checksum]

      # Adds the rows to the memories, of feelings about code that's since changed or gone.
      def append_memories(rows)
        return if rows.empty?

        header = !File.exist?(@memories)
        CSV.open(@memories, 'a') do |csv|
          csv << HEADER if header
          rows.each { csv << it.values_at(*HEADER) }
        end
      end

      def write_rows(rows)
        FileUtils.mkdir_p(File.dirname(@csv))
        CSV.open(@csv, 'w') do |csv|
          csv << HEADER
          rows.each { csv << it.values_at(*HEADER) }
        end
        @rows = @felt = @felt_methods = nil
      end

      def where(method) = "#{relative(method.path)}:#{method.line}"

      def relative(path) = path.delete_prefix(File.join(@root, ''))

      def commit
        sha, status = Open3.capture2('git', '-C', @root, 'rev-parse', '--short', 'HEAD', err: File::NULL)
        sha.strip if status.success?
      rescue SystemCallError
        nil
      end
    end
  end
end
