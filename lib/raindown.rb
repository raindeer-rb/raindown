# frozen_string_literal: true

require 'commonmarker'
require 'antlers'
require 'antlers/api'

require_relative 'elements'
require_relative 'raindown/bare_directives'
require_relative 'raindown/code'
require_relative 'raindown/config'
require_relative 'raindown/directives'
require_relative 'raindown/front_matter'
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

  # Stands in for an app's metadata when there isn't any, so list: and files: list nothing.
  module NoMetadata
    def self.list(**) = []
  end

  # Headings with an id, which are the ones a table of contents links to.
  HEADINGS = 'h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]'

  module_function

  # Directives show in bold, unless the file's project hides them in .raindown/config.yml.
  def render_file(path:, metadata: NoMetadata, bare: false, hide_directives: Config.for(path)[:hide_directives])
    render(markdown: File.read(path), metadata:, bare: bare || BareDirectives.file?(path), hide_directives:)
  end

  # Front matter keys are variables, like {title} or <{ title }>.
  # Directives like "toc:" export to HTML as bold or comments depending on hide_directives config.
  def render(markdown:, metadata: NoMetadata, bare: false, hide_directives: false)
    variables = variables(markdown:)
    template = html(markdown:, variables:, metadata:, bare:)
    context = { document: markdown, metadata:, bare: }

    if template.include?('<{')
      # Directives whose output is HTML. The rest rendered before Commonmarker, in PreRenderer.
      ast = Antlers.ast(template:, elements: Antlers::Elements[:html, :prop, :slot] + Elements[:endpoint])
      template = "#{Antlers.render(ast:, current_binding: variables.binding, metadata:).chomp}\n"
    end

    # Nodes and directives render last, so their HTML isn't read as Markdown or directives.
    Directives.render(Nodes.render_placeholders(template, **context), hide: hide_directives)
  end

  # The HTML from Commonmarker, after PreRenderer and before the directives whose output is HTML.
  def html(markdown:, variables:, metadata: NoMetadata, bare: false)
    markdown = NodeBlocks.to_rendered(markdown.dup.force_encoding('UTF-8'), metadata:, bare:)
    markdown = PreRenderer.render(markdown, variables:, metadata:, bare:)
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
