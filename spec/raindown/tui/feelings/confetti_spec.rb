# frozen_string_literal: true

require 'raindown/tui/feelings/scene'

RSpec.describe Raindown::TUI::Confetti do
  def lines(tick) = Raindown::TUI::Scene.new(width: 90, height: 20, animations: [described_class]).lines(tick)
  def text(lines) = lines.map { it.map(&:text).join }
  def columns(lines) = text(lines).flat_map { |line| line.chars.each_index.reject { line[it] == ' ' } }

  it 'drifts bright flecks down either side, clear of the middle' do
    frames = (0..10).map { lines(it) }
    middle = (90 / 2) - (Raindown::TUI::Balloons::MIDDLE / 2)..(90 / 2) + (Raindown::TUI::Balloons::MIDDLE / 2)

    expect(frames.map { text(it).join }.join).to match(/[▪◆▴·]/)
    expect(frames.flat_map { columns(it) }.uniq & middle.to_a).to be_empty
    expect(frames.flatten.reject { it.style == :blank }.map(&:style).uniq).to all(start_with('bright_'))
  end

  it 'falls a row or two each frame, as fast as the rain' do
    falling = [0, 1].map { |tick| text(lines(tick)) }

    expect(falling.first).not_to eq(falling.last)
  end
end
