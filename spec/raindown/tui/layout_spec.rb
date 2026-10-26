# frozen_string_literal: true

require 'raindown/tui/layout'
require 'raindown/tui/navigator'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::Layout do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.join(File.realpath(dir), 'docs')
      FileUtils.mkdir_p(File.join(@root, 'guides'))
      File.write(File.join(@root, 'guides', 'setup.md'),
                 "# Setup\n\n<{ endpoint: }>\n```sh\ncurl https://example.com\n```\n```json\n{}\n```\n<{ :endpoint }>\n")
      File.write(File.join(@root, 'README.md'), "# Readme\n")
      example.run
    end
  end

  let(:navigator) { Raindown::TUI::Navigator.new(root: @root) }

  def text(lines) = lines.map { |segments| segments.map(&:text).join }
  def width(line) = Unicode::DisplayWidth.of(line)

  it 'lays out the title, the files beside the outline, the status and the buttons, each line the full width' do
    lines = described_class.new(navigator, width: 60, height: 7).lines

    expect(text(lines).map(&:rstrip)).to eq(
      [' raindown  docs  guides/setup.md',
       ' ▾ guides/          │ # Setup',
       '   setup.md         │   endpoint:                 [+3] [Run]',
       ' README.md          │',
       '                    │',
       ' Tab switches panes, Enter opens and folds, q quits',
       ' Tab Pane  Enter Open  x Run  e Edit  w Write back']
    )
    expect(text(lines).map { width(it) }).to all(eq(60))
  end

  it 'highlights the cursor, brightly in the focused pane' do
    lines = described_class.new(navigator, width: 60, height: 7).lines

    expect(lines[1].first.style).to eq(:selected)
    expect(lines[1].last.style).to eq(:cursor)
    expect(lines[2].last(2).map(&:style)).to eq(%i[button button])
  end

  it 'sends events from rows and buttons when clicked' do
    lines = described_class.new(navigator, width: 80, height: 7).lines

    expect(lines[2].first.event).to eq([:select, :files, 1])
    expect(lines[1].last.event).to eq([:select, :outline, 0])
    expect(lines[2].last.event).to eq([:press, :outline, 1, :execute])
    expect(lines.last.map(&:event).compact.uniq).to eq(%i[tab enter execute edit write_back reload quit])
  end

  it 'cuts text that does not fit, and leaves out buttons that do not fit' do
    lines = described_class.new(navigator, width: 40, height: 7).lines

    expect(text(lines)[5]).to eq(' Tab switches panes, Enter opens and fo…')
    expect(text(lines).map { width(it) }).to all(eq(40))
    expect(lines.last.map(&:event).compact.uniq).to eq(%i[tab enter execute edit])
  end

  it 'shows only the status when the screen is too short for the panes' do
    expect(text(described_class.new(navigator, width: 30, height: 2).lines).map(&:rstrip))
      .to eq([' Tab switches panes, Enter op…'])
  end
end
