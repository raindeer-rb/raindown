# frozen_string_literal: true

require 'raindown'

RSpec.describe Raindown::PreRenderer do
  def render(markdown, **values)
    described_class.render(markdown, variables: Raindown::Variables.new(values))
  end

  def braces(text)
    text.gsub(/[{}]/, Raindown::CODE_BRACES)
  end

  describe '.render' do
    it 'renders {var} and <{ var }> anywhere' do
      expect(render("# Notes for {name}\n\n<{ name }> wrote this.\n", name: 'Mark')).to eq("# Notes for Mark\n\nMark wrote this.\n")
    end

    it 'escapes {var} values as HTML, but not <{ var }>, and leaves Markdown in both' do
      expect(render("{title}\n<{ title }>\n", title: '*Big* <notes>')).to eq("*Big* &lt;notes&gt;\n*Big* <notes>\n")
    end

    it 'hides braces in values from Antlers' do
      expect(render("{title}\n", title: '{x}')).to eq("#{braces('{x}')}\n")
    end

    it 'renders nested values' do
      expect(render("By {author.name}\n", author: { name: 'Mark' })).to eq("By Mark\n")
    end

    it 'renders a loop on its own lines as one list' do
      expect(render("<{ for: tag in: tags }>\n- {tag}\n<{ :for }>\n", tags: %w[ruby markdown])).to eq("- ruby\n- markdown\n")
    end

    it 'renders a condition' do
      markdown = "<{ if: draft }>\n**Draft**\n<{ :if }>\nText\n"

      expect(render(markdown, draft: true)).to eq("**Draft**\nText\n")
      expect(render(markdown, draft: false)).to eq("Text\n")
    end

    it 'keeps the whitespace around the Markdown' do
      expect(render("\n\n{name}\n\n", name: 'Mark')).to eq("\n\nMark\n\n")
    end

    it 'leaves front matter alone' do
      expect(render("---\ntitle: '{name}'\n---\n\n{name}\n", name: 'Mark')).to eq("---\ntitle: '{name}'\n---\n\nMark\n")
    end

    {
      'a code span' => "The `{name}` variable\n",
      'a fenced code block' => "```\n# {name}\n```\n",
      'an indented code block' => "Text\n\n    {name}\n",
      'a code block in a quote' => "> ```\n> {name}\n> ```\n"
    }.each do |description, markdown|
      it "leaves variables in #{description} alone" do
        expect(render(markdown, name: 'Mark')).to eq(braces(markdown))
      end
    end

    it 'renders components as fragments, with loop variables in their props and slots' do
      require 'helpers/components'
      Raindown::Fragments.collect do
        rendered = render("<{ for: n in: names }>\n<{ SpecCard: name=n }>\n**{n}**\n<{ :SpecCard }>\n<{ :for }>\n", names: %w[Ann Bob])

        expect(Raindown::Fragments.fill(rendered)).to eq(<<~HTML)
          <section data-name="Ann"><p><strong>Ann</strong></p>
          </section>

          <section data-name="Bob"><p><strong>Bob</strong></p>
          </section>

        HTML
      end
    end

    it 'renders a list of pages as one list' do
      metadata = Class.new do
        def list(folder:) = [{ title: "#{folder} 1" }, { title: "#{folder} 2" }].map { Raindown::Variables.new(it) }
      end.new
      markdown = "<{ list: page folder: 'notes' }>\n- {page.title}\n<{ :list }>\n"

      expect(described_class.render(markdown, variables: Raindown::Variables.new({}), metadata:)).to eq("- notes 1\n- notes 2\n")
    end
  end
end
