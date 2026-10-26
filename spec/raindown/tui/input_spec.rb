# frozen_string_literal: true

require 'raindown/tui/input'
require 'raindown/tui/layout'

RSpec.describe Raindown::TUI::Input do
  describe '.key_event' do
    it "turns curses' keys, which are strings or numbers, into events" do
      expect(described_class.key_event('j')).to eq(:down)
      expect(described_class.key_event(Curses::KEY_UP)).to eq(:up)
      expect(described_class.key_event(9)).to eq(:tab)
      expect(described_class.key_event(13)).to eq(:enter)
      expect(described_class.key_event(Curses::KEY_ENTER)).to eq(:enter)
      expect(described_class.key_event('z')).to be_nil
    end
  end

  describe '.zones' do
    it 'finds what was clicked by its row and column, counting wide characters as two columns' do
      segment = Raindown::TUI::Layout::Segment
      lines = [[segment.new(text: '界 ', style: :title, event: nil), segment.new(text: '[Run]', style: :button, event: :execute)],
               [segment.new(text: 'row', style: :file, event: [:press, :files, 0, :enter])]]
      zones = described_class.zones(lines)

      expect(described_class.click(zones, column: 3, row: 0)).to eq(:execute)
      expect(described_class.click(zones, column: 2, row: 0)).to be_nil
      expect(described_class.click(zones, column: 1, row: 1)).to eq([:press, :files, 0, :enter])
      expect(described_class.click(zones, column: 9, row: 1)).to be_nil
    end
  end

  describe '.mouse_event' do
    # Stands in for curses' MouseEvent, which only getmouse makes.
    let(:mouse) { Struct.new(:bstate, :x, :y) }
    let(:zones) { [[0, 0...5, :execute]] }

    it 'clicks with the left button, and does nothing when scrolling' do
      expect(described_class.mouse_event(mouse.new(Curses::BUTTON1_PRESSED, 2, 0), zones)).to eq(:execute)
      expect(described_class.mouse_event(mouse.new(Curses::BUTTON1_CLICKED, 2, 0), zones)).to eq(:execute)
      expect(described_class.mouse_event(mouse.new(Curses::BUTTON1_PRESSED, 2, 1), zones)).to be_nil
      expect(described_class.mouse_event(mouse.new(Curses::BUTTON4_PRESSED, 2, 0), zones)).to be_nil
      # Older ncurses reports scrolling down with no button of its own.
      expect(described_class.mouse_event(mouse.new(0, 2, 0), zones)).to be_nil
    end
  end
end
