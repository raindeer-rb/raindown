# frozen_string_literal: true

require 'commonmarker'
require 'antlers'
require 'antlers/api'
require 'nokogiri'
require_relative 'elements'
require_relative 'raindown/bare_directives'
require_relative 'raindown/code'
require_relative 'raindown/front_matter'
require_relative 'raindown/pre_renderer'
require_relative 'raindown/variables'

module Raindown
  # Antlers evaluates any braces in the HTML, so braces in code are swapped for placeholders
  # then HTML entities, which browsers still display as braces.
  CODE_BRACES = { '{' => "\u{E000}", '}' => "\u{E001}" }.freeze
  CODE_BRACE_ENTITIES = { "\u{E000}" => '&#123;', "\u{E001}" => '&#125;' }.freeze

  # The Markdown TOC injected by TOCInjector, which the <{ :toc }> directive replaces in HTML.
  INJECTED_TOC = %r{\n*<!-- raindown:toc -->.*?<!-- /raindown:toc -->}m

  # Front matter is metadata, so it's left out of the HTML and the headings.
  MARKDOWN_OPTIONS = { extension: { alerts: true, front_matter_delimiter: '---' } }.freeze
  # Directives are HTML comments until Antlers renders them, and escaped characters like "\#" stay plain text.
  HTML_OPTIONS = { render: { unsafe: true, escaped_char_spans: false } }.freeze

  # Stands in for an app's metadata when there isn't any, so a <{ list: }> lists nothing.
  module NoMetadata
    def self.list(**) = []
  end

  # Headings with an id, which are the ones a table of contents links to.
  HEADINGS = 'h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]'

  module_function

  def headings(markdown:, metadata: NoMetadata, bare: false)
    html = html(markdown:, variables: variables(markdown:), metadata:, bare:)

    Nokogiri::HTML(html).css(HEADINGS).map do |heading|
      { level: heading.name[1].to_i, text: heading.text.strip, id: heading['id'] }
    end
  end

  def render_file(path:, metadata: NoMetadata, bare: false)
    render(markdown: File.read(path), metadata:, bare: bare || BareDirectives.file?(path))
  end

  # Front matter keys are variables, like {title} or <{ title }>.
  def render(markdown:, metadata: NoMetadata, bare: false)
    variables = variables(markdown:)
    template = html(markdown:, variables:, metadata:, bare:)
    return template unless template.include?('<{')

    # Directives whose output is HTML. The rest rendered before Commonmarker, in PreRenderer.
    ast = Antlers.ast(template:, elements: Antlers::Elements[:html, :prop, :slot] + Elements[:toc, :endpoint])

    "#{Antlers.render(ast:, current_binding: variables.binding, metadata:).chomp}\n"
  end

  # The HTML from Commonmarker, after PreRenderer and before the directives whose output is HTML.
  def html(markdown:, variables:, metadata:, bare:)
    markdown = PreRenderer.render(markdown.dup.force_encoding('UTF-8'), variables:, metadata:, bare:)
    doc = Commonmarker.parse(hide_directives(markdown:), options: MARKDOWN_OPTIONS)
    preserve_code(doc:)

    doc.to_html(options: HTML_OPTIONS).gsub('<!-- ANTLERS', '<{').gsub('ANTLERS -->', '}>')
       .gsub(/[\u{E000}\u{E001}]/, CODE_BRACE_ENTITIES)
  end

  def variables(markdown:)
    Variables.new(FrontMatter.parse(markdown).first)
  end

  # Commonmarker escapes directives, so they're hidden in HTML comments until it's done.
  def hide_directives(markdown:)
    markdown.gsub(INJECTED_TOC, '').gsub('<{', '<!-- ANTLERS').gsub('}>', 'ANTLERS -->').force_encoding('UTF-8')
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
