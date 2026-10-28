# frozen_string_literal: true

require 'raindown/tui/scene'

RSpec.describe Raindown::TUI::Fireworks do
  def frames(animations) = (0..60).map { Raindown::TUI::Scene.new(width: 60, height: 16, animations:).lines(it) }
  def text(lines) = lines.map { it.map(&:text).join }

  it 'rises rockets that burst into sparks, flying out and fading, in bright colours' do
    frames = frames([described_class])
    sparks = frames.map { text(it).join }.join

    expect(sparks).to include('╵').and include('*').and include('+').and include('·')
    expect(frames.flatten.map(&:style).uniq - [:blank]).to all(start_with('bright_'))
    expect(text(frames.first).map(&:length)).to all(eq(60))
  end

  it 'draws over the rain, which still falls around it' do
    over = frames([Raindown::TUI::Rain, described_class]).map { text(it).join }.join

    expect(over).to include('*').and include('│').and include('◦')
  end
end
