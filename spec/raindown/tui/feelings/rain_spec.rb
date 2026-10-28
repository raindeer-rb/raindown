# frozen_string_literal: true

require 'raindown/tui/feelings/scene'
require 'unicode/display_width'

RSpec.describe Raindown::TUI::Rain do
  let(:rain) { Raindown::TUI::Scene.new(width: 40, height: 12, animations: [described_class]) }

  def text(lines) = lines.map { it.map(&:text).join }

  it 'fills the lines, with drops in bright colours, a colour each time they fall' do
    lines = (0..60).map { rain.lines(it) }
    colors = lines.flatten.map(&:style).uniq - [:blank]

    expect(text(lines[0]).map { Unicode::DisplayWidth.of(it) }).to all(eq(40))
    expect([colors, colors.length]).to match([all(start_with('bright_')), be > 3])
  end

  it 'drops fall a row or two a tick, and splash at the bottom' do
    frames = (0..30).map { text(rain.lines(it)) }

    expect(frames.map { it.first(11).join }.uniq.length).to be > 1
    expect(frames.first(11).join).to include('│').and include('╎')
    expect(frames.map(&:last).join).to include('◦').and include('·').and include('.')
  end
end
