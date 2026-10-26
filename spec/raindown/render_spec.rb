# frozen_string_literal: true

require 'raindown'
require 'cgi/escape'
require 'tmpdir'

RSpec.describe Raindown do
  describe '.render' do
    def text(html)
      CGI.unescapeHTML(html.gsub(/<[^>]*>/, ''))
    end

    context 'with front matter variables' do
      def render(front_matter, body)
        described_class.render(markdown: "---\n#{front_matter}\n---\n\n#{body}\n")
      end

      it 'renders {var} escaped and <{ var }> raw' do
        html = render('title: <b>Notes</b>', "{title}\n\n<{ title }>")

        expect(html).to include('<p>&lt;b&gt;Notes&lt;/b&gt;</p>')
        expect(html).to include('<b>Notes</b>')
      end

      it 'renders dates, numbers and nested values' do
        html = render("date: 2026-10-13\ncount: 3\nauthor:\n  name: Mark", "{date}\n\n{count}\n\n{author.name}")

        expect(html).to include('<p>2026-10-13</p>', '<p>3</p>', '<p>Mark</p>')
      end

      it 'renders variables in headings, their ids and the table of contents' do
        html = render('name: Mark', "# Notes for {name}\n\n<{ :toc }>")

        expect(html).to include('<h1 id="notes-for-mark">Notes for Mark')
        expect(html).to include("<a href='#notes-for-mark'>Notes for Mark</a>")
      end

      it 'renders a raw variable that is not a string' do
        expect(render("date: 2026-10-13\ncount: 3", '<{ date }> and <{ count }>')).to include('2026-10-13 and 3')
      end

      it 'keeps the spaces around a variable' do
        expect(render('name: Mark', 'Hello {name}, welcome')).to include('<p>Hello Mark, welcome</p>')
      end

      it 'loops over lists and checks conditions' do
        html = render("tags: [ruby, markdown]\ndraft: false\npublished: true",
                      "<{ for: tag in: tags }>[{tag}]<{ :for }>\n\n<{ if: draft }>Draft<{ :if }><{ if: published }>Live<{ :if }>")

        expect(text(html)).to include('[ruby][markdown]')
        expect(text(html)).to include('Live')
        expect(text(html)).not_to include('Draft')
      end

      it 'renders a loop on its own lines as one list' do
        html = render('tags: [ruby, markdown]', "<{ for: tag in: tags }>\n1. {tag}\n<{ :for }>")

        expect(html).to include("<ol>\n<li>ruby</li>\n<li>markdown</li>\n</ol>")
      end

      it 'renders a loop as table rows' do
        rows = "<{ for: person in: people }>\n| {person.name} |\n<{ :for }>"
        html = render("people:\n  - name: Ann\n  - name: Bo", "| Name |\n| --- |\n#{rows}")

        expect(html).to include("<tbody>\n<tr>\n<td>Ann</td>\n</tr>\n<tr>\n<td>Bo</td>\n</tr>\n</tbody>")
      end

      it 'renders Markdown in a condition at the start of a line' do
        expect(render('draft: true', '<{ if: draft }>**Draft**<{ :if }> notes')).to include('<p><strong>Draft</strong> notes</p>')
      end

      it 'renders Markdown in values' do
        expect(render('title: My *great* notes', '{title}')).to include('<p>My <em>great</em> notes</p>')
      end

      it 'renders variables in underlined headings' do
        expect(render('name: Mark', "Notes for {name}\n===")).to include('<h1 id="notes-for-mark">Notes for Mark')
      end

      it 'renders braces in values as text' do
        expect(text(render('title: "{x}"', '{title}'))).to include('{x}')
      end

      it 'renders keys named like Ruby methods' do
        expect(text(render('hash: abc', '{hash}'))).to include('abc')
      end

      it 'renders nothing for unknown variables and none of render itself' do
        expect(text(render('title: Notes', '[{missing}{markdown}{metadata}{headings}]'))).to include('[]')
      end

      it 'renders nothing without front matter' do
        expect(text(described_class.render(markdown: "[{title}]\n"))).to include('[]')
      end
    end

    it 'lists nothing for a list directive without metadata' do
      html = described_class.render(markdown: "<{ list: page folder: 'notes' }>\n- {page.title}\n<{ :list }>\n\nAfter\n")

      expect(html).to eq("<p>After</p>\n")
    end

    it 'keeps directives in code blocks as-is' do
      html = described_class.render(markdown: "```\n<{ :toc }>\n```\n")

      expect(text(html)).to include('<{ :toc }>')
      expect(html).not_to include('Table of contents')
    end

    it 'leaves front matter out of the HTML' do
      html = described_class.render(markdown: "---\ntitle: Notes\n---\n\n# Title\n")

      expect(html).not_to include('title: Notes')
      expect(html).not_to include('<hr')
    end

    it 'renders bare directives when asked' do
      expect(described_class.render(markdown: "# Title\n\n:toc\n", bare: true)).to include('Table of contents')
      expect(described_class.render(markdown: "# Title\n\n:toc\n")).not_to include('Table of contents')
    end

    it 'renders bare directives in Markdown with raindown: true front matter' do
      expect(described_class.render(markdown: "---\nraindown: true\n---\n\n# Title\n\n:toc\n")).to include('Table of contents')
      expect(described_class.render(markdown: "---\nraindown: false\n---\n\n# Title\n\n:toc\n")).not_to include('Table of contents')
    end

    it 'renders an endpoint as its code blocks, between its directive and end tag in bold' do
      { '<{ endpoint: :x }>' => 'endpoint: :x', '<{ endpoint: }>' => 'endpoint:' }.each do |directive, text|
        html = described_class.render(markdown: "#{directive}\n\n```sh\ncurl https://api.example.com\n```\n<{ :endpoint }>\n")

        expect(html).to start_with("<p><strong>#{text}</strong></p>\n<pre").and end_with("</pre>\n<p><strong>:endpoint</strong></p>\n")
        expect(text(html)).to include('curl https://api.example.com')
      end
    end

    it 'renders node blocks with their HTML, or their Markdown when they have no HTML' do
      require 'helpers/nodes'
      html = described_class.render(markdown: "SpecReleases: limit=1\n- old\n\nSpecHeading: title='Hi'\n\nText.\n", bare: true)

      expect(html).to match(%r{\A<p><strong>SpecReleases: limit=1</strong></p>\n<ol data-count="\d+"><li>1.2.0</li></ol>\n})
        .and include("<p><strong>SpecHeading: title=&#39;Hi&#39;</strong></p>\n<h2 id=\"hi\">Hi")
      expect(html).not_to include('old')
      expect(html).to include('<p>Text.</p>')
    end

    it 'renders directives as HTML comments with hide_directives' do
      html = described_class.render(markdown: "<{ endpoint: }>\n\n```sh\ncurl x\n```\n<{ :endpoint }>\n", hide_directives: true)

      expect(html).to start_with("<!-- endpoint: -->\n<pre").and end_with("</pre>\n<!-- :endpoint -->\n")
      expect(html).not_to include('<strong>')
    end

    it 'raises when an endpoint is not closed' do
      expect { described_class.render(markdown: "<{ endpoint: :x }>\n\n```sh\ncurl x\n```\n") }
        .to raise_error(Antlers::Parser::ParserError, /Missing end tag/)
    end

    it 'keeps braces in code blocks' do
      html = described_class.render(markdown: "```ruby\nh = { a: 1 }\n```\n")

      expect(text(html)).to include('h = { a: 1 }')
    end

    it 'keeps braces in inline code' do
      html = described_class.render(markdown: "Use `<{` and `}>` around `x = { b: 2 }`.\n")

      expect(text(html)).to include('Use <{ and }> around x = { b: 2 }.')
    end

    it 'highlights code blocks' do
      expect(described_class.render(markdown: "```ruby\nputs 1\n```\n")).to include('<pre lang="ruby" style=')
    end

    it 'leaves code blocks unhighlighted with a language class when asked, for highlighting in the browser' do
      html = described_class.render(markdown: "```ruby\nh = { a: 1 }\n```\n", highlight_code: false)

      expect(html).to include('<pre><code class="language-ruby">')
      expect(html).not_to include('style=')
      expect(text(html)).to include('h = { a: 1 }')
    end

    it "leaves an endpoint's code unhighlighted when asked" do
      html = described_class.render(markdown: "<{ endpoint: }>\n\n```sh\ncurl x\n```\n<{ :endpoint }>\n", highlight_code: false)

      expect(html).to include('<pre><code class="language-sh">')
      expect(html).not_to include('style=')
    end

    it 'ends with a single newline' do
      plain = described_class.render(markdown: "# Title\n")
      directive = described_class.render(markdown: "# Title\n\n<{ :toc }>\n\nText.\n")

      expect([plain, directive]).to all(end_with("\n").and(satisfy { |html| !html.end_with?("\n\n") }))
    end

    it 'renders a toc: block as the HTML TOC in place of its Markdown one' do
      ["# Title\n\n<{ toc: }>\n\n- [Title](#title)\n\n<{ :toc }>\n\nText.\n",
       "# Title\n\ntoc:\n- [Title](#title)\n\nText.\n"].each do |markdown|
        html = described_class.render(markdown:, bare: true)

        expect(html.scan('Table of contents').length).to eq(1)
        expect(html).not_to include('<a href="#title">')
        expect(html).to include('<p>Text.</p>')
      end
    end

    it 'still renders directives outside code' do
      html = described_class.render(markdown: "# Title\n\n<{ :toc }>\n\n```\n<{ :toc }>\n```\n")

      expect(html.scan('Table of contents').length).to eq(1)
    end
  end

  describe '.render_file' do
    def render_file(name, markdown, bare: false)
      Dir.mktmpdir do |dir|
        path = File.join(dir, name)
        File.write(path, markdown)
        described_class.render_file(path:, bare:)
      end
    end

    it 'renders bare directives in Raindown files' do
      expect(render_file('notes.rd', "# Title\n\n:toc\n")).to include('Table of contents')
      expect(render_file('notes.raindown', "# Title\n\n:toc\n")).to include('Table of contents')
    end

    it 'renders bare for and if directives around the Markdown block below them' do
      markdown = "---\ntags: [a, b]\ndraft: false\n---\n\nfor: tag in: tags\n- {tag}\n\nif: draft\nA draft.\n\nAfter.\n"
      html = render_file('notes.rd', markdown)

      expect(html).to include("<ul>\n<li>a</li>\n<li>b</li>\n</ul>")
      expect(html).not_to include('A draft.')
      expect(html).to include('<p>After.</p>')
    end

    it 'leaves bare directives as text in Markdown files' do
      html = render_file('notes.md', "# Title\n\n:toc\n")

      expect(html).not_to include('Table of contents')
      expect(html).to include('<p>:toc</p>')
    end

    it 'renders bare directives in Markdown files when asked' do
      expect(render_file('notes.md', "# Title\n\n:toc\n", bare: true)).to include('Table of contents')
    end

    it 'keeps bare directives in code as-is' do
      html = render_file('notes.rd', "# Title\n\n```\n:toc\n```\n")

      expect(html).not_to include('Table of contents')
      expect(html).to include(':toc')
    end
  end

  describe '.headings' do
    it 'lists nothing for a list directive' do
      markdown = "# Title\n\n<{ list: page folder: 'notes' }>\n## {page.title}\n<{ :list }>\n"

      expect(Raindown::TOC.new.headings(markdown:).map { |h| h[:text] }).to eq(['Title'])
    end

    it 'leaves out front matter' do
      expect(Raindown::TOC.new.headings(markdown: "---\ntitle: Notes\n---\n\n# Title\n").map { |h| h[:text] }).to eq(['Title'])
    end

    it 'reads frozen Markdown without changing it' do
      markdown = "# Title\n".encode('ASCII-8BIT').freeze

      expect(Raindown::TOC.new.headings(markdown:)).to eq([{ level: 1, text: 'Title', id: 'title' }])
      expect(markdown.encoding).to eq(Encoding::ASCII_8BIT)
    end
  end
end
