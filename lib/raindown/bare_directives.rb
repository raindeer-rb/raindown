# frozen_string_literal: true

require_relative 'code_blocks'
require_relative 'front_matter'

module Raindown
  # Raindown files (.rd/.raindown) can write a directive like <{ if: draft }> as a bare if: draft on its own line.
  # Markdown files opt in with "raindown: true" in their front matter, or with the --bare flag.
  # Nodes like toc: and files: are handled by NodeBlocks, before the rest.
  #
  # Bare directives have no end tag. A bare block directive closes itself after the content it applies to,
  # so where a block needs to wrap more than that, write it with delimiters and an end tag instead:
  #   <{ if: draft }>
  #   ...
  #   <{ :if }>
  module BareDirectives
    EXTENSIONS = %w[.rd .raindown].freeze
    # The block directives, and the method that finds the line their end tag goes after.
    BLOCK_KEYWORDS = { 'endpoint:' => :after_endpoint, 'for:' => :after_block, 'if:' => :after_block,
                       'list:' => :after_block }.freeze
    # Four spaces of indent would make the line a Markdown code block.
    LINE = /\A( {0,3})((#{BLOCK_KEYWORDS.keys.join('|')})(?:[ \t]+\S.*?)?)[ \t]*$/
    # An end tag on its own line, like one a bare block directive above added, ends a block.
    END_TAG = /\A {0,3}<\{\s*:[a-z][\w-]*\s*\}>[ \t]*$/

    module_function

    def enabled?(path: nil, content: nil, bare: false)
      bare || file?(path) || front_matter?(content)
    end

    def file?(path)
      return false if path.nil?

      EXTENSIONS.include?(File.extname(path).downcase)
    end

    # Whether the front matter has "raindown: true". Front matter that isn't valid YAML fails when the file renders,
    # so here it only means no.
    def front_matter?(content)
      return false unless content&.start_with?('---')

      FrontMatter.parse(content).first[:raindown] == true
    rescue Psych::Exception
      false
    end

    # Wrap each bare directive in Antlers delimiters and close its block, leaving code and front matter as-is.
    def expand(content)
      lines = content.lines
      index = FrontMatter.line_count(lines)

      while index < lines.length
        block = CodeBlocks.at(lines, index)
        index = (block ? block[:close] : expand_line(lines, index)) + 1
      end

      lines.join
    end

    # The directive in Antlers delimiters, or nil when the line isn't a bare directive.
    def wrap(line)
      line.sub(LINE) { "#{::Regexp.last_match(1)}<{ #{::Regexp.last_match(2)} }>" } if line.match?(LINE)
    end

    # Returns the index of the last line it handled. That's the directive itself, so the lines it holds
    # are expanded too, and a bare directive inside it closes before it does.
    def expand_line(lines, index)
      match = lines[index].match(LINE)
      return index unless match

      lines[index] = wrap(lines[index])
      close_block(lines, index, indent: match[1], keyword: match[3])
      index
    end

    def close_block(lines, index, indent:, keyword:)
      last = public_send(BLOCK_KEYWORDS[keyword], lines, index + 1) || index
      lines[last] = "#{lines[last]}\n" unless lines[last].end_with?("\n")
      lines.insert(last + 1, "#{indent}<{ :#{keyword.delete_suffix(':')} }>\n")
    end

    # The last line of the curl snippet and response below an endpoint.
    def after_endpoint(lines, index)
      CodeBlocks.endpoint(lines, index).last&.fetch(:close)
    end

    # The last line of the Markdown block below, after any blank lines: up to the next blank line or end tag,
    # with fenced code kept whole. Nil when there's nothing below.
    def after_block(lines, index)
      index = CodeBlocks.skip_blank_lines(lines, index)
      last = nil

      while index < lines.length && !lines[index].strip.empty? && !lines[index].match?(END_TAG)
        last = CodeBlocks.at(lines, index)&.fetch(:close) || index
        index = last + 1
      end

      last
    end
  end
end
