# frozen_string_literal: true

require_relative 'feelings_log'

module Raindown
  module TUI
    # Code feelings' bins below the code box, one for each temper, best to worst, each a box with its key's number, its
    # temper and a bar of how many feelings it holds, highlighted when it's the chosen temper:
    #    ╭─ 01 ────╮ ╭─ 02 ────╮ ╭─ 03 ────╮ ╭─ 04 ────╮ ╭─ 05 ────╮
    #    │ FROLIC  │ │ NUMB    │ │ WOE     │ │ DREAD   │ │ MALICE  │
    #    │ ███░  9 │ │ ████ 41 │ │ ██░░  6 │ │ █░░░  3 │ │ █░░░  2 │
    #    ╰─────────╯ ╰─────────╯ ╰─────────╯ ╰─────────╯ ╰─────────╯
    module Bins
      # A bin's lines.
      BIN_LINES = 4

      private

      # The five bins, each a box with its number, its temper, and a bar of how many feelings it holds.
      def bins
        counts = view.log.counts
        most = [counts.values.max, 1].max
        chosen = chosen_temper
        boxes = counts.each_with_index.map { |(temper, count), index| bin(index + 1, temper, count, most, chosen) }

        Array.new(BIN_LINES) do |line|
          padded([segment('', :blank, width: 1), *boxes.flat_map { [it[line], segment(' ', :blank, width: 1)] }])
        end
      end

      # The temper being noted, or else how the selected method felt, if it's been felt.
      def chosen_temper = view.noting || view.log.temper(view.selected)

      # As wide as they all fit, which cuts their borders short in a pane too narrow for them.
      def bin_width = [(width - 1 - FeelingsLog::TEMPERS.length) / FeelingsLog::TEMPERS.length, 1].max

      # A space inside a bin's sides, unless the longest temper would only fit without it.
      def bin_inside
        return '' if bin_width < FeelingsLog::TEMPERS.map(&:length).max + 4

        ' '
      end

      # The bin's lines, highlighted when it's the chosen temper: the one being noted, or how the selected method felt.
      def bin(number, temper, count, most, chosen)
        style = :feelings
        style = :selected if temper == chosen
        bin_lines(number, temper, count, most).map { segment(it, style, width: bin_width) }
      end

      # Its key's number on its top line, its temper, the bar of its count, and its bottom.
      def bin_lines(number, temper, count, most)
        inside = bin_inside
        name = temper.upcase.ljust(bin_width - 2 - (2 * inside.length))
        ["╭─ 0#{number} #{'─' * [bin_width - 7, 0].max}╮", "│#{inside}#{name}#{inside}│",
         "│#{inside}#{bar(count, most)} #{count}#{inside}│", "╰#{'─' * (bin_width - 2)}╯"]
      end

      # As long as there's room beside the count, and filled as far as its share of the fullest bin's.
      def bar(count, most)
        length = bin_width - 3 - (2 * bin_inside.length) - count.to_s.length
        filled = (length * count / most.to_f).round
        "#{'█' * filled}#{'░' * (length - filled)}"
      end
    end
  end
end
