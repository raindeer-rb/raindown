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

  module_function

  def headings(markdown:)
    markdown = PreRenderer.render(markdown.dup.force_encoding('UTF-8'), variables: variables(markdown:))
    html = Commonmarker.parse(markdown, options: MARKDOWN_OPTIONS).to_html(options: HTML_OPTIONS)

    Nokogiri::HTML(html).css('h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]').map do |heading|
      { level: heading.name[1].to_i, text: heading.text.strip.gsub(/[\u{E000}\u{E001}]/, CODE_BRACES.invert), id: heading['id'] }
    end
  end

  def render_file(path:, metadata: {}, bare: false)
    render(markdown: File.read(path), metadata:, bare: bare || BareDirectives.file?(path))
  end

  # Front matter keys are variables, like {title} or <{ title }>.
  def render(markdown:, metadata: {}, bare: false)
    variables = variables(markdown:)
    markdown = PreRenderer.render(markdown, variables:, bare:)
    doc = Commonmarker.parse(hide_directives(markdown:), options: MARKDOWN_OPTIONS)
    preserve_code(doc:)

    template = doc.to_html(options: HTML_OPTIONS)
    template = template.gsub('<!-- ANTLERS', '<{').gsub('ANTLERS -->', '}>').gsub(/[\u{E000}\u{E001}]/, CODE_BRACE_ENTITIES)

    return template unless template.include?('<{') || template.include?('{')

    ast = Antlers.ast(template:, elements: Antlers::Elements[:html, :var, :prop, :slot, :if, :for] + Elements[:toc, :list, :endpoint])

    "#{Antlers.render(ast:, current_binding: variables.binding, metadata:).chomp}\n"
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
