# frozen_string_literal: true

require 'raindown/tui'

RSpec.describe Raindown::TUI do
  describe '.start' do
    it 'stops without a terminal, once curses has loaded' do
      allow($stdin).to receive(:tty?).and_return(false)

      expect { described_class.start('.') }.to raise_error(SystemExit).and output("raindown tui needs a terminal\n").to_stderr
      expect(defined?(Curses)).to eq('constant')
    end
  end
end
