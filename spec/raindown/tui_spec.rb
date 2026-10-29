# frozen_string_literal: true

require 'raindown/tui'

RSpec.describe Raindown::TUI do
  describe '.start' do
    it 'says it needs a terminal, once curses has loaded, and returns false to be watched instead' do
      allow($stdin).to receive(:tty?).and_return(false)

      expect { expect(described_class.start('.')).to be(false) }
        .to output("raindown needs a terminal, so it's watching instead\n").to_stderr
      expect(defined?(Curses)).to eq('constant')
    end
  end
end
