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
      HEADER = %w[when where method temper note commit].freeze

      attr_reader :page

      def initialize(root:)
        @root = root
        @csv = File.join(root, '.raindown', 'feelings.csv')
        @tempers = File.join(root, '.raindown', 'tempers.csv')
        @page = File.join(root, 'docs', 'code-feelings.md')
      end

      def add(feeling)
        FileUtils.mkdir_p(File.dirname(@csv))
        header = !File.exist?(@csv)
        CSV.open(@csv, 'a') do |csv|
          csv << HEADER if header
          csv << [Date.today.iso8601, where(feeling.method), feeling.method.label, feeling.temper, feeling.note, commit]
        end
        write_tempers
        write_page
      end

      def rows
        return [] unless File.exist?(@csv)

        CSV.read(@csv, headers: true).map(&:to_h)
      end

      # How many feelings there are of each temper, in the bins' order.
      def counts
        tally = rows.map { it['temper'] }.tally
        TEMPERS.to_h { [it, tally.fetch(it, 0)] }
      end

      private

      def where(method) = "#{method.path.delete_prefix(File.join(@root, ''))}:#{method.line}"

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
        cells = row.values_at(*HEADER).map { it.to_s.gsub('|', '\|') }
        "| #{cells.join(' | ')} |"
      end
    end
  end
end
