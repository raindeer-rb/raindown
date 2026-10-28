# frozen_string_literal: true

require 'raindown/tui/feelings/scene'

RSpec.describe Raindown::TUI::Sparkles do
  def lines(tick) = Raindown::TUI::Scene.new(width: 90, height: 24, animations: [described_class]).lines(tick)
  def text(lines) = lines.map { it.map(&:text).join }
  def spots(lines) = text(lines).each_with_index.flat_map { |line, row| line.chars.each_index.reject { line[it] == ' ' }.map { [row, it] } }

  it 'twinkles white sparkles from dots to stars around the waffle, never on it' do
    frames = (0..80).map { lines(it) }
    waffle_rows = ((24 - Raindown::TUI::BakedWaffle.down) / 2)...((24 + Raindown::TUI::BakedWaffle.down) / 2)
    waffle_columns = ((90 - Raindown::TUI::BakedWaffle.across) / 2)...((90 + Raindown::TUI::BakedWaffle.across) / 2)
    spots = frames.flat_map { spots(it) }

    expect(frames.map { text(it).join }.join).to include('·').and include('✧').and include('✦')
    expect(frames.flatten.reject { it.style == :blank }.map(&:style).uniq).to eq([:shine])
    expect(spots.uniq.select { |row, column| waffle_rows.cover?(row) && waffle_columns.cover?(column) }).to be_empty
  end
end
