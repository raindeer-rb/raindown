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

    # The feelings everyone's sorted, kept in .raindown/feelings.csv with the commit they were felt at, and written to
    # docs/code-feelings.md as a chart of how many there are of each temper, and a table, newest first.
    # A write-back draws the chart, from .raindown/tempers.csv.
    class FeelingsLog
      TEMPERS = %w[woe frolic dread malice numb].freeze
      HEADER = %w[when where method temper note commit checksum].freeze
      # The page's table leaves out the checksum.
      TABLE = %w[when where method temper note commit].freeze

      attr_reader :page

      def initialize(root:)
        @root = root
        @csv = File.join(root, '.raindown', 'feelings.csv')
        @tempers = File.join(root, '.raindown', 'tempers.csv')
        @page = File.join(root, 'docs', 'code-feelings.md')
      end

      # Adds the feeling, as the newest, in place of one about the method before, unless its code's changed since,
      # which keeps that one too.
      def add(feeling)
        method = feeling.method
        row = HEADER.zip([Date.today.iso8601, where(method), method.label, feeling.temper, feeling.note, commit, method.checksum]).to_h
        write_rows(rows.reject { felt_row?(it, method) } + [row])
        write_tempers
        write_page
      end

      # Read once, and again after a feeling's added.
      def rows
        return [] unless File.exist?(@csv)

        @rows ||= CSV.read(@csv, headers: true).map(&:to_h)
      end

      # Whether the method's been felt, by its file, name and code's checksum, wherever its line is now. A row from before
      # checksums were kept has none, so it counts until the method's felt again.
      def felt?(method)
        @felt ||= rows.to_set { [it['where'].sub(/:\d+\z/, ''), it['method'], it['checksum'].to_s] }
        [method.checksum, ''].any? { @felt.include?([relative(method.path), method.label, it]) }
      end

      # How many feelings there are of each temper, in the bins' order.
      def counts
        tally = rows.map { it['temper'] }.tally
        TEMPERS.to_h { [it, tally.fetch(it, 0)] }
      end

      private

      def felt_row?(row, method)
        row['where'].sub(/:\d+\z/, '') == relative(method.path) && row['method'] == method.label &&
          [method.checksum, ''].include?(row['checksum'].to_s)
      end

      def write_rows(rows)
        FileUtils.mkdir_p(File.dirname(@csv))
        CSV.open(@csv, 'w') do |csv|
          csv << HEADER
          rows.each { csv << it.values_at(*HEADER) }
        end
        @rows = @felt = nil
      end

      def where(method) = "#{relative(method.path)}:#{method.line}"

      def relative(path) = path.delete_prefix(File.join(@root, ''))

      def commit
        sha, status = Open3.capture2('git', '-C', @root, 'rev-parse', '--short', 'HEAD', err: File::NULL)
        sha.strip if status.success?
      rescue SystemCallError
        nil
      end

      def write_tempers
        CSV.open(@tempers, 'w') do |csv|
          csv << %w[temper feelings]
          counts.each { |temper, count| csv << [temper, count] }
        end
      end

      def write_page
        FileUtils.mkdir_p(File.dirname(@page))
        File.write(@page, <<~MARKDOWN)
          # Code feelings

          How the code felt, sorted with `raindown tui`'s Code feelings by Severance's four tempers, or numb.
          Each row is a method someone sorted, at the commit it was felt at.

          <{ chart: '.raindown/tempers.csv' width: 30 }>
          <{ :chart }>

          | When | Where | Method | Temper | Note | Commit |
          | ---- | ----- | ------ | ------ | ---- | ------ |
          #{rows.reverse.map { table_row(it) }.join("\n")}
        MARKDOWN
      end

      def table_row(row)
        cells = row.values_at(*TABLE).map { it.to_s.gsub('|', '\|') }
        "| #{cells.join(' | ')} |"
      end
    end
  end
end
