# frozen_string_literal: true

require 'raindown/tui/terminal/input'
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
      expect(described_class.key_event('E')).to eq(:edit)
      expect(described_class.key_event('Q')).to eq(:quit)
      expect(%w[f 1 6].map { described_class.key_event(it) }).to eq(%i[feelings bin1 bin6])
      expect([20, "\x14"].map { described_class.key_event(it) }).to eq(%i[celebrate celebrate])
    end
  end

  describe '.typing_event' do
    it 'types printable characters, even the ones that are keys, and keeps the keys that move, choose, close and delete' do
      expect(%w[j q / A].map { described_class.typing_event(it) }).to eq(%w[j q / A].map { Raindown::TUI::Type.new(text: it) })
      expect([Curses::KEY_DOWN, 13, 27, 127].map { described_class.typing_event(it) }).to eq(%i[down enter escape backspace])
      expect(described_class.typing_event(Curses::KEY_LEFT)).to be_nil
      expect(described_class.key_event('j', typing: true)).to eq(Raindown::TUI::Type.new(text: 'j'))
    end
  end

  describe '.zones' do
    it 'finds what was clicked by its row and column, counting wide characters as two columns' do
      segment = Raindown::TUI::Text::Segment
      lines = [[segment.new(text: '界 ', style: :title, event: nil), segment.new(text: '[Run]', style: :button, event: :execute)],
               [segment.new(text: 'row', style: :file, event: Raindown::TUI::Click.new(pane: :nav, index: 0, action: :enter))]]
      zones = described_class.zones(lines)

      expect(described_class.click(zones, column: 3, row: 0)).to eq(:execute)
      expect(described_class.click(zones, column: 2, row: 0)).to be_nil
      expect(described_class.click(zones, column: 1, row: 1)).to eq(Raindown::TUI::Click.new(pane: :nav, index: 0, action: :enter))
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

    it 'hovers over what a click there would send, as the mouse moves' do
      moved = Curses::REPORT_MOUSE_POSITION
      expect(described_class.mouse_event(mouse.new(moved, 2, 0), zones)).to eq(Raindown::TUI::Hover.new(target: :execute))
      expect(described_class.mouse_event(mouse.new(moved, 2, 1), zones)).to eq(Raindown::TUI::Hover.new(target: nil))
    end
  end
end
