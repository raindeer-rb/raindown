# frozen_string_literal: true

require 'raindown/tui/terminal/ncurses_shim'

RSpec.describe Raindown::TUI::NcursesShim do
  around do |example|
    term = ENV.fetch('TERM', nil)
    example.run
  ensure
    ENV['TERM'] = term
  end

  def term_while_starting(term, version)
    ENV['TERM'] = term
    described_class.starting(version:) { ENV.fetch('TERM', nil) }
  end

  it "starts old ncurses as xterm-256color for a terminal whose entry isn't the system's, and puts TERM back after" do
    allow(described_class).to receive(:system_entry?).with('xterm-ghostty').and_return(false)

    expect(term_while_starting('xterm-ghostty', 'ncurses 6.0.20150808')).to eq('xterm-256color')
    expect(ENV.fetch('TERM', nil)).to eq('xterm-ghostty')
  end

  it "keeps the terminal's own entry with newer ncurses, or when it's the system's" do
    allow(described_class).to receive(:system_entry?).and_return(false)
    expect(term_while_starting('xterm-ghostty', 'ncurses 6.4.20221231')).to eq('xterm-ghostty')

    allow(described_class).to receive(:system_entry?).with('screen-256color').and_return(true)
    expect(term_while_starting('screen-256color', 'ncurses 6.0.20150808')).to eq('screen-256color')
  end

  it 'finds system entries by their first letter, or its hex code like on macOS' do
    allow(File).to receive(:exist?).and_return(false)
    allow(File).to receive(:exist?).with('/usr/share/terminfo/78/xterm-256color').and_return(true)

    expect(described_class.system_entry?('xterm-256color')).to be(true)
    expect(described_class.system_entry?('xterm-ghostty')).to be(false)
  end
end
