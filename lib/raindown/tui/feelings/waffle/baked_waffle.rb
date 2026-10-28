# frozen_string_literal: true

module Raindown
  module TUI
    # A waffle's rows, as [text, style] parts: a grid of pockets between golden ridges, shaded darker at their tops,
    # under the ridges, so they look deep, with rounded corners, and a pat of butter melting where the middle ridges cross,
    # with a white shine at its top left, and as many of its pockets as have been filled with syrup, nearest the butter
    # first:
    #     ▄███████████████████████▄
    #     █▓▓▓▓▓█▓▓▓▓▓█▓▓▓▓▓█▓▓▓▓▓█
    #     █░░░░░█░░░░░█░░░░░█░░░░░█
    #     █████████████████████████
    #     █▓▓▓▓▓█▓▓▓▓▓█▓▓▓▓▓█▓▓▓▓▓█
    #     █░░░░░█░░░▄▄▄▄▄░░░█░░░░░█
    #     ██████████████████████████
    module BakedWaffle
      RIDGE = :code_number
      POCKET = :bright_orange
      BUTTER = :button
      SHINE = :shine
      SYRUP = :syrup
      # The pockets across and down, the columns each takes, and the lines a pocket and a ridge take.
      POCKETS = 4
      POCKET_WIDTH = 5
      ROW_LINES = 3
      # The pat of butter's lines, from the line above the middle ridge, a drip below it, and the shine at its top left, as
      # its lines and columns.
      PAT = %w[▄▄▄▄▄ █████ ▀▀█▀▀].freeze
      DRIP = '▀'
      SHINE_AT = [[0, 0], [0, 1], [1, 0]].freeze

      module_function

      def rows(syrup: 0)
        cells = Array.new(down) { |row| Array.new(across) { |column| cell(row, column, across, down) } }
        buttered(sweetened(cells, syrup), down / 2, across / 2).map { parts(it) }
      end

      def across = 1 + (POCKETS * (POCKET_WIDTH + 1))
      def down = 1 + (POCKETS * ROW_LINES)

      # The cells with as many pockets filled with syrup, nearest the middle first, keeping their shading.
      def sweetened(cells, filled)
        pockets.first(filled).each do |pocket_row, pocket_column|
          (1...ROW_LINES).to_a.product((1..POCKET_WIDTH).to_a).each do |line, offset|
            cells[(pocket_row * ROW_LINES) + line][(pocket_column * (POCKET_WIDTH + 1)) + offset][1] = SYRUP
          end
        end
        cells
      end

      # The pockets, by their row and column, nearest the middle first.
      def pockets
        middle = (POCKETS - 1) / 2.0
        (0...POCKETS).to_a.product((0...POCKETS).to_a).sort_by { |row, column| [(row - middle).abs + (column - middle).abs, row, column] }
      end

      # A ridge, rounded at its corners, or a pocket, darker at its top, under the ridge above it, than below.
      def cell(row, column, across, down)
        edge = [0, down - 1].include?(row)
        return [' ', :blank] if edge && [0, across - 1].include?(column)
        return ['▄', RIDGE] if row.zero? && [1, across - 2].include?(column)
        return ['▀', RIDGE] if edge && [1, across - 2].include?(column)
        return ['█', RIDGE] if (row % ROW_LINES).zero? || (column % (POCKET_WIDTH + 1)).zero?

        [%w[▓ ░][(row % ROW_LINES) - 1], POCKET]
      end

      # The cells with the pat of butter on the middle ridges' cross, its drip, and its shine.
      def buttered(cells, row, column)
        PAT.each_with_index do |line, at|
          line.each_char.with_index { |char, offset| cells[row - 1 + at][column - 2 + offset] = [char, BUTTER] }
        end
        cells[row + 2][column] = [DRIP, BUTTER]
        shine(cells, row, column)
      end

      # The cells with the butter's top left shining.
      def shine(cells, row, column)
        SHINE_AT.each { |line, offset| cells[row - 1 + line][column - 2 + offset][1] = SHINE }
        cells
      end

      # The row's cells in runs of the same style, as [text, style] parts.
      def parts(row) = row.chunk_while { |cell, after| cell[1] == after[1] }.map { [it.map(&:first).join, it[0][1]] }
    end
  end
end
