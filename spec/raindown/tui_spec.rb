# frozen_string_literal: true

require 'raindown/tui'
require 'raindown/tui/saves'
require 'raindown/tui/terminal/screen'

RSpec.describe Raindown::TUI do
  describe '.start' do
    it 'says it needs a terminal, once curses has loaded, and returns false to be watched instead' do
      allow($stdin).to receive(:tty?).and_return(false)

      expect { expect(described_class.start('.')).to be(false) }
        .to output("raindown needs a terminal, so it's watching instead\n").to_stderr
      expect(defined?(Curses)).to eq('constant')
    end

    it 'returns true once it has quit, so it is not watched after' do
      [$stdin, $stdout].each { allow(it).to receive(:tty?).and_return(true) }
      allow(Raindown::TUI::Saves).to receive(:new).and_return(instance_double(Raindown::TUI::Saves, stop: nil))
      allow(Raindown::TUI::Screen).to receive(:new).and_return(instance_double(Raindown::TUI::Screen, run: nil))

      expect(described_class.start(Dir.pwd)).to be(true)
    end
  end
end
