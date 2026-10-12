# frozen_string_literal: true

require 'commonmarker'
require 'antlers'
require 'antlers/api'
require 'nokogiri'
require_relative 'elements'

module Raindown
  # Antlers evaluates any braces in the HTML, so braces in code are swapped for placeholders
  # then HTML entities, which browsers still display as braces.
  CODE_BRACES = { '{' => "\u{E000}", '}' => "\u{E001}" }.freeze
  CODE_BRACE_ENTITIES = { "\u{E000}" => '&#123;', "\u{E001}" => '&#125;' }.freeze

  # The Markdown TOC injected by "raindown toc", which the <{ :toc }> directive replaces in HTML.
  INJECTED_TOC = %r{\n*<!-- raindown:toc -->.*?<!-- /raindown:toc -->}m

  module_function

  def headings(markdown:)
    html = Commonmarker.parse(markdown.force_encoding('UTF-8'), options: { extension: { alerts: true } })
                       .to_html(options: { render: { unsafe: true } })

    Nokogiri::HTML(html).css('h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]').map do |heading|
      { level: heading.name[1].to_i, text: heading.text.strip, id: heading['id'] }
    end
  end

  def render(markdown:, metadata: {})
    template = markdown.gsub(INJECTED_TOC, '').gsub('<{', '<!-- ANTLERS').gsub('}>', 'ANTLERS -->')

    doc = Commonmarker.parse(template.force_encoding('UTF-8'), options: { extension: { alerts: true } })
    preserve_code(doc:)

    template = doc.to_html(options: { render: { unsafe: true } })
    template = template.gsub('<!-- ANTLERS', '<{').gsub('ANTLERS -->', '}>').gsub(/[\u{E000}\u{E001}]/, CODE_BRACE_ENTITIES)

    return template unless template.include?('<{') || template.include?('{')

    ast = Antlers.ast(template:, elements: Antlers::Elements[:html, :var, :prop, :slot, :if, :for] + Rain::Elements[:toc, :list])

    "#{Antlers.render(ast:, current_binding: binding, metadata:).chomp}\n"
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
