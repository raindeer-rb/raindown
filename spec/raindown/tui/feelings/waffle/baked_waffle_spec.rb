# frozen_string_literal: true

require 'raindown/tui/feelings/waffle/baked_waffle'

RSpec.describe Raindown::TUI::BakedWaffle do
  let(:rows) { described_class.rows }
  let(:text) { rows.map { |parts| parts.map(&:first).join } }

  it 'bakes pockets between ridges, shaded darker at their tops, with rounded corners' do
    expect(text.map(&:length)).to all(eq(25))
    expect(text.values_at(0, 1, 2, 3, -1)).to eq([" ▄#{'█' * 21}▄ ", "█#{'▓▓▓▓▓█' * 4}", "█#{'░░░░░█' * 4}", '█' * 25, " ▀#{'█' * 21}▀ "])
    expect(rows[1].map(&:last)).to eq(%i[code_number bright_orange] * 4 + [:code_number])
  end

  it 'melts a pat of butter where the middle ridges cross, shining white at its top left' do
    styled = ->(style) { rows.each_with_index.flat_map { |parts, row| parts.select { it.last == style }.map { [row, it.first] } } }

    expect(styled[:button]).to eq([[5, '▄▄▄'], [6, '████'], [7, '▀▀█▀▀'], [8, '▀']])
    expect(styled[:shine]).to eq([[5, '▄▄'], [6, '█']])
  end

  it 'fills its pockets with syrup, nearest the butter first, keeping their shading' do
    # Each pocket's 10 cells are shaded, apart from the 8 under the butter.
    syrupy = ->(filled) { described_class.rows(syrup: filled).flat_map { |parts| parts.select { it.last == :syrup }.map(&:first) }.join }

    expect([syrupy[0], syrupy[4].scan(/[▓░]/).length, syrupy[16].scan(/[▓░]/).length]).to eq(['', (4 * 10) - 8, (16 * 10) - 8])
    expect(described_class.pockets.first(4)).to contain_exactly([1, 1], [1, 2], [2, 1], [2, 2])
  end
end
