# frozen_string_literal: true

require 'commonmarker'
require 'antlers'
require 'antlers/api'

require_relative 'elements'
require_relative 'raindown/bare_directives'
require_relative 'raindown/code'
require_relative 'raindown/config'
require_relative 'raindown/directives'
require_relative 'raindown/fragments'
require_relative 'raindown/front_matter'
require_relative 'raindown/heading_ids'
require_relative 'raindown/node_blocks'
require_relative 'raindown/pages'
require_relative 'raindown/pre_renderer'
require_relative 'raindown/variables'

module Raindown
  # Antlers evaluates any braces in the HTML, so braces in code are swapped for placeholders
  # then HTML entities, which browsers still display as braces.
  CODE_BRACES = { '{' => "\u{E000}", '}' => "\u{E001}" }.freeze
  CODE_BRACE_ENTITIES = { "\u{E000}" => '&#123;', "\u{E001}" => '&#125;' }.freeze

  # Front matter is metadata, so it's left out of the HTML and the headings.
  MARKDOWN_OPTIONS = { extension: { alerts: true, front_matter_delimiter: '---' } }.freeze
  # Directives are HTML comments until Antlers renders them, and escaped characters like "\#" stay plain text.
  HTML_OPTIONS = { render: { unsafe: true, escaped_char_spans: false } }.freeze
  # Without highlighting, code blocks are left for the browser to highlight, like <pre><code class="language-ruby">.
  UNHIGHLIGHTED_OPTIONS = { render: { **HTML_OPTIONS[:render], github_pre_lang: false } }.freeze

  # Stands in for an app's metadata when there isn't any, so list: and files: list nothing.
  module NoMetadata
    def self.list(**) = []
  end

  # Headings with an id, which are the ones a table of contents links to.
  HEADINGS = 'h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]'

  module_function

  # Directives show in bold and code is highlighted, unless the file's project changes them in .raindown/config.yml.
  def render_file(path:, metadata: NoMetadata, bare: false, **options)
    options = Config.render_options(path).merge(options)
    render(markdown: File.read(path, encoding: Encoding::UTF_8), metadata:, bare: bare || BareDirectives.file?(path), **options)
  end

  # Front matter keys are variables, like {title} or <{ title }>.
  # Directives like "toc:" export to HTML as bold or comments depending on hide_directives config.
  # Code blocks are highlighted, unless highlight_code is false for a site that highlights code in the browser.
  def render(markdown:, metadata: NoMetadata, bare: false, hide_directives: false, highlight_code: true)
    highlighting(highlight_code) do
      Fragments.collect do
        # Components' HTML goes back in, then their headings get unique ids, before nodes like the TOC see it.
        html = assembled(markdown:, metadata:, bare:)
        html = Nodes.render_placeholders(html, document: markdown, metadata:, bare:, html:)

        Directives.render("#{html.chomp}\n", hide: hide_directives)
      end
    end
  end

  # Whether code is highlighted while the block runs, like one document's render,
  # so components and endpoints rendering their own Markdown follow it too.
  def highlighting(highlight_code)
    outer = Thread.current[:raindown_highlight_code]
    Thread.current[:raindown_highlight_code] = highlight_code
    yield
  ensure
    Thread.current[:raindown_highlight_code] = outer
  end

  def highlight_code?
    Thread.current[:raindown_highlight_code] != false
  end

  # The document's HTML with its components' HTML put back, and unique heading ids.
  def assembled(markdown:, metadata: NoMetadata, bare: false)
    HeadingIds.unique(Fragments.fill(html(markdown:, variables: variables(markdown:), metadata:, bare:)))
  end

  # The document's HTML from Commonmarker, after nodes and the template pass, with components as fragments.
  def html(markdown:, variables:, metadata: NoMetadata, bare: false)
    markdown = NodeBlocks.to_rendered(markdown.dup.force_encoding('UTF-8'), metadata:, bare:)
    commonmark(PreRenderer.render(markdown, variables:, metadata:, bare:))
  end

  # Markdown to HTML, like a document's or a component's slot.
  def commonmark(markdown)
    doc = Commonmarker.parse(hide_directives(markdown:), options: MARKDOWN_OPTIONS)
    preserve_code(doc:)

    html = highlight_code? ? doc.to_html(options: HTML_OPTIONS) : unhighlighted_html(doc:)
    html.gsub('<!-- ANTLERS', '<{').gsub('ANTLERS -->', '}>')
        .gsub(/[\u{E000}\u{E001}]/, CODE_BRACE_ENTITIES)
  end

  # Code blocks without highlighting, with a language class for highlighting in the browser.
  def unhighlighted_html(doc:)
    doc.to_html(options: UNHIGHLIGHTED_OPTIONS, plugins: { syntax_highlighter: nil })
  end

  def variables(markdown:)
    Variables.new(FrontMatter.parse(markdown).first)
  end

  # Commonmarker escapes directives, so they're hidden in HTML comments until it's done.
  def hide_directives(markdown:)
    markdown.gsub('<{', '<!-- ANTLERS').gsub('}>', 'ANTLERS -->').force_encoding('UTF-8')
  end

  # Restore directives in code and hide its braces from Antlers.
  def preserve_code(doc:)
    doc.walk do |node|
      next unless %i[code code_block].include?(node.type)

      node.string_content = node.string_content.gsub('<!-- ANTLERS', '<{').gsub('ANTLERS -->', '}>')
                                .gsub(/[{}]/, CODE_BRACES)
    end
  end
end
