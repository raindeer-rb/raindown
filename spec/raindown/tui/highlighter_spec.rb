# frozen_string_literal: true

require 'raindown/tui/highlighter'

RSpec.describe Raindown::TUI::Highlighter do
  it "highlights code by its file's name, each line as [text, style] parts by the kind of token" do
    lines = described_class.lines(['def area # the size', '  "square"'], filename: 'shapes.rb')

    expect(lines).to eq([[['def', :code_keyword], [' ', :code], ['area', :code_function], [' ', :code], ['# the size', :code_comment]],
                         [['  ', :code], ['"square"', :code_string]]])
  end

  it "highlights code by its code block's language, keeping blank lines" do
    lines = described_class.lines(['{', '', '  "id": 1', '}'], language: 'json')

    expect(lines.map { |parts| parts.map(&:last).uniq - [:code] }).to eq([[], [], %i[code_constant code_number], []])
  end

  it 'highlights the code blocks in Markdown in their own languages' do
    lines = described_class.lines(['```json', '{"ok": true}', '```'], language: 'markdown')

    expect(lines[1]).to include(['"ok"', :code_constant], ['true', :code_keyword])
  end

  it "leaves code in a language it doesn't know plain" do
    expect(described_class.lines(['just text'], filename: 'notes.unknown')).to eq([[['just text', :code]]])
    expect(described_class.lines(['x'], language: 'not-a-language')).to eq([[['x', :code]]])
  end
end
