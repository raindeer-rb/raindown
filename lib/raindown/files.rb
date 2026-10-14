# frozen_string_literal: true

require_relative 'node'

module Raindown
  # The node behind files:, a list of links to the files the metadata has for its props, like files: folder: 'notes'.
  # A project can change how files are listed with its own Files node in .raindown, like "class Files < Raindown::Files".
  class Files < Node
    def initialize(**tags)
      @tags = tags
    end

    # Each file has its front matter, its path and its content.
    def files(metadata: NoMetadata)
      metadata.list(**@tags)
    end

    def replace(metadata: NoMetadata)
      files(metadata:).map { |file| "- [#{file.title || file.path}](#{file.path})" }.join("\n")
    end
  end
end
