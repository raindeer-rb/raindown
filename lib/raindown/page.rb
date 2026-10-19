# frozen_string_literal: true

module Raindown
  # A file that Pages lists: its front matter and implicit metadata, like page.title, page.folder,
  # page.order and page.path, and its content rendered to HTML when it's asked for.
  class Page
    attr_reader :file_path, :metadata

    def initialize(file_path:, metadata:, render_options: {})
      @file_path = file_path
      @metadata = metadata
      @render_options = render_options
    end

    # Rendered when asked for, so a file that lists itself doesn't render forever.
    # The front matter is rendered with it, so its variables work, and a Raindown file's bare directives too.
    def content
      @content ||= begin
        markdown = File.read(file_path, encoding: Encoding::UTF_8)

        if FrontMatter.parse(markdown).last.strip.empty? then ''
        else Raindown.render(markdown:, bare: BareDirectives.file?(file_path), **@render_options)
        end
      end
    end

    def [](key)
      key.to_sym == :content ? content : metadata[key.to_sym]
    end

    def respond_to_missing?(name, include_all = false)
      metadata.key?(name) || super
    end

    # Unknown keys are nil, like front matter a file doesn't have.
    def method_missing(name, *args)
      return super unless args.empty? && !name.end_with?('=', '?', '!')

      metadata[name]
    end
  end
end
