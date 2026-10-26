# frozen_string_literal: true

require 'raindown/tui/card'

RSpec.describe Raindown::TUI::Card do
  subject(:card) do
    described_class.new(project: '/docs', path: '/docs/notes.md', line: 3, heading: 'Sales', directive: "chart: '1 2 3'",
                        chart: ['▁▅█'])
  end

  it 'has a title of its file, from its project, and the heading above it' do
    expect(card.title).to eq('notes.md › Sales')
    expect(card.with(heading: nil).title).to eq('notes.md')
  end

  it 'is as wide as its chart, within a range of widths, and with its border' do
    expect(card.width).to eq(3)
    expect(card.box_width).to eq(7)
    expect(card.box_width(within: 28..40)).to eq(28)
    expect([card.height, card.box_height]).to eq([3, 5])
  end

  it 'formats each line in its border, with the title in its style, and blank lines below it' do
    lines = (0..5).map { card.format_line(it, box_width: 14, title_style: :selected) }

    expect(lines).to eq(
      [[['╭────────────╮', :border, 14]],
       [['│ ', :border, 2], ['notes.md › Sales', :selected, 10], [' │', :border, 2]],
       [['│ ', :border, 2], ["chart: '1 2 3'", :directive, 10], [' │', :border, 2]],
       [['│ ', :border, 2], ['▁▅█', :chart, 10], [' │', :border, 2]],
       [['╰────────────╯', :border, 14]],
       [['', :blank, 14]]]
    )
  end
end
