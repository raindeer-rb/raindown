# frozen_string_literal: true

require 'raindown'

RSpec.describe Raindown::PreRenderer do
  def render(markdown, **values)
    described_class.render(markdown, variables: Raindown::Variables.new(values))
  end

  describe '.render' do
    it 'renders {var} and <{ var }> in headings' do
      expect(render("# Notes for {name}\n\n## <{ name }>\n", name: 'Mark')).to eq("# Notes for Mark\n\n## Mark\n")
    end

    it 'escapes {var} values as Markdown, but not <{ var }>' do
      expect(render("# {title}\n# <{ title }>\n", title: 'C# *notes*'))
        .to eq("# C\\# \\*notes\\*\n# C# *notes*\n")
    end

    it 'hides braces in values from Antlers' do
      expect(render("# {title}\n", title: '{x}')).to eq("# \u{E000}x\u{E001}\n")
    end

    it 'renders nested values' do
      expect(render("# By {author.name}\n", author: { name: 'Mark' })).to eq("# By Mark\n")
    end

    {
      'a paragraph' => "Notes for {name}\n",
      'a code span in a heading' => "# The `{name}` variable\n",
      'a fenced code block' => "```\n# {name}\n```\n",
      'a directive' => "# Notes <{ :toc }>\n",
      'front matter' => "---\n# {name}\n---\n"
    }.each do |description, markdown|
      it "leaves #{description} alone" do
        expect(render(markdown, name: 'Mark')).to eq(markdown)
      end
    end
  end
end
