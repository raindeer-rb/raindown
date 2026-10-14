# frozen_string_literal: true

require 'raindown/table_formatter'

RSpec.describe Raindown::TableFormatter do
  def rewrite(content)
    described_class.rewrite(content:, path: 'sample.md')
  end

  describe '.rewrite' do
    it 'pads every column to its widest cell' do
      expect(rewrite(<<~MARKDOWN)).to eq(<<~MARKDOWN)
        | Command | Description |
        |-|-|
        | render | Render once |
        | watch | Re-render on save |
      MARKDOWN
        | Command | Description       |
        | ------- | ----------------- |
        | render  | Render once       |
        | watch   | Re-render on save |
      MARKDOWN
    end

    it 'keeps alignment markers and aligns cells to match' do
      expect(rewrite(<<~MARKDOWN)).to eq(<<~MARKDOWN)
        | Left | Center | Right | None |
        |:-|:-:|-:|-|
        | a | b | c | d |
      MARKDOWN
        | Left | Center | Right | None |
        | :--- | :----: | ----: | ---- |
        | a    |   b    |     c | d    |
      MARKDOWN
    end

    it 'adds outer pipes when they are missing' do
      expect(rewrite("a | bb\n-|-\nccc | d\n")).to eq(<<~MARKDOWN)
        | a   | bb  |
        | --- | --- |
        | ccc | d   |
      MARKDOWN
    end

    it 'keeps escaped pipes in their cell' do
      expect(rewrite("| a | b |\n|-|-|\n| x \\| y | z |\n")).to eq(<<~MARKDOWN)
        | a      | b   |
        | ------ | --- |
        | x \\| y | z   |
      MARKDOWN
    end

    it 'pads rows that are missing cells' do
      expect(rewrite("| a | b |\n|-|-|\n| c |\n")).to eq(<<~MARKDOWN)
        | a   | b   |
        | --- | --- |
        | c   |     |
      MARKDOWN
    end

    it 'leaves tables with extra cells as they are' do
      table = "| a | b |\n|-|-|\n| c | d | e |\n"

      expect(rewrite(table)).to eq(table)
    end

    it 'keeps the indent of indented tables' do
      expect(rewrite("- Item\n\n  | a | bb |\n  |-|-|\n  | c | d |\n")).to eq(<<~MARKDOWN)
        - Item

          | a   | bb  |
          | --- | --- |
          | c   | d   |
      MARKDOWN
    end

    it 'ignores tables inside fenced code' do
      markdown = "```\n| a | b |\n|-|-|\n| ccc | d |\n```\n"

      expect(rewrite(markdown)).to eq(markdown)
    end

    it 'leaves other lines with pipes alone' do
      markdown = "Use a | b in text.\n\n| not | a table |\n"

      expect(rewrite(markdown)).to eq(markdown)
    end

    it 'formats each table and the text around them' do
      markdown = "Intro\n\n| a | b |\n|-|-|\n| ccc | d |\n\nMiddle\n\n| e |\n|-|\n| fffff |\n\nEnd\n"

      expect(rewrite(markdown)).to eq(<<~MARKDOWN)
        Intro

        | a   | b   |
        | --- | --- |
        | ccc | d   |

        Middle

        | e     |
        | ----- |
        | fffff |

        End
      MARKDOWN
    end

    it 'counts wide characters as two columns' do
      expect(rewrite("| a | b |\n|-|-|\n| 日本語 | 🎉 |\n| 👨‍👩‍👧 | 🇯🇵 |\n")).to eq(<<~MARKDOWN)
        | a      | b   |
        | ------ | --- |
        | 日本語 | 🎉  |
        | 👨‍👩‍👧     | 🇯🇵  |
      MARKDOWN
    end

    it 'counts combining marks as zero columns' do
      expect(rewrite("| a | b |\n|-|-|\n| cafés | x |\n")).to eq(<<~MARKDOWN)
        | a     | b   |
        | ----- | --- |
        | cafés | x   |
      MARKDOWN
    end

    it 'centers and right-aligns wide characters by display width' do
      expect(rewrite("| left | center | right |\n|:-|:-:|-:|\n| 日 | 日 | 日 |\n")).to eq(<<~MARKDOWN)
        | left | center | right |
        | :--- | :----: | ----: |
        | 日   |   日   |    日 |
      MARKDOWN
    end

    it 'is idempotent' do
      once = rewrite("| a | b |\n|:-:|-:|\n| ccc | d |\n")

      expect(rewrite(once)).to eq(once)
    end
  end
end
