# frozen_string_literal: true

require 'raindown/tui/feelings/celebration/scene'

RSpec.describe Raindown::TUI::Balloons do
  def lines(tick) = Raindown::TUI::Scene.new(width: 60, height: 16, animations: [described_class]).lines(tick)
  def text(lines) = lines.map { it.map(&:text).join }
  def tops(lines) = text(lines).each_index.select { |row| text(lines)[row].include?('▄███▄') }

  it 'floats balloons up in bright colours, shaded, with knots, on strings that kink' do
    frames = (0..60).map { lines(it) }

    expect(text(frames.first).map(&:length)).to all(eq(60))
    expect(frames.map { text(it).join }.join).to include('▄███▄').and include('█░▒████').and include('▼').and include('╰╮')
    expect(frames.flatten.select { it.text.match?(/[▄▀█░▒▼]/) }.map(&:style).uniq).to all(start_with('bright_'))
  end

  it 'rises a row every few frames' do
    rise = Raindown::TUI::Balloons::RISE_FRAMES
    risen = (0..20).map { |step| tops(lines(step * rise)) }.each_cons(2).find { |now, later| now.any? && later.any? }

    expect(risen.last.min).to eq(risen.first.min - 1)
  end
end
