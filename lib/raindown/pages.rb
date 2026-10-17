# frozen_string_literal: true

require_relative 'front_matter'
require_relative 'page'

module Raindown
  # The metadata of a project's Markdown files, which list: and files: list by tag.
  # Ported from Raindeer's Rain::Pages, and takes the same Dirload metadata.
  #
  # Each file is tagged with its front matter, like "tags: [ruby, docs]" or "date: 2099", and by its path,
  # where underscored folders are metadata: docs/_basics/_1-getting-started.md has
  #   folder: basics, order: 1, path: docs/_basics/_1-getting-started.md
  # Folder tags can share a folder name with "&", like docs/_1&_basics/getting-started.md.
  # An app can add its own metadata by subclassing and overriding implicit_metadata, like Raindeer's URL paths.
  class Pages
    EXTENSIONS = %w[md rd markdown raindown].freeze
    SEGMENTS = Regexp.union(['/', '&', '-'])

    class << self
      # The Markdown files under a project's root, the folder with its .raindown folder or else the file's folder.
      def for(path)
        file_directory = File.dirname(File.expand_path(path))
        load(root: Nodes.find_folder(file_directory)&.then { File.dirname(it) } || file_directory)
      end

      # Lists the files under the root with Dirload, without loading them.
      def load(root:)
        require 'dirload'
        file_types = Dirload.file_paths(absolute_path: root).group_by { Dirload.extension(file_path: it) }
        new(metadata: Dirload::Metadata.new(loaded_paths: {}, missed_paths: [], file_types:), root:)
      end
    end

    # Render options, like hide_directives: true, are for rendering each listed file's content.
    def initialize(metadata:, root:, render_options: {})
      @root = root
      @render_options = render_options
      @file_paths = metadata.file_types.values_at(*EXTENSIONS).flatten.compact
      @metadata = {}
      @tags = {}

      @file_paths.each { |file_path| process(file_path:) }
    end

    # The files with any of the tags, like list(folder: 'basics') or list(tags: 'ruby'), sorted by order.
    # Without tags, every file.
    def list(**tags)
      file_paths = tags.empty? ? @file_paths : tagged(**tags)
      file_paths.sort_by { |file_path| sort_key(file_path) }.map { |file_path| listed_page(file_path) }
    end

    def tagged(**tags)
      tags.flat_map { |type, tag| @tags.dig(type.to_sym, tag) || [] }.uniq
    end

    private

    def listed_page(file_path)
      Page.new(file_path:, metadata: @metadata[file_path], render_options: @render_options)
    end

    def process(file_path:)
      metadata = implicit_metadata(file_path:).merge(FrontMatter.parse(File.read(file_path)).first)
      @metadata[file_path] = metadata
      metadata.each { |type, tag| Array(tag).each { |item| tag(type:, tag: item, file_path:) } }
    end

    # The path is relative to the root, like docs/_basics/_1-getting-started.md.
    # A subclass can add or replace metadata here, like Raindeer's Rain::Pages replacing the path with a URL path.
    def implicit_metadata(file_path:)
      { folder: folders(file_path:).last, order: order(file_path:), path: relative(file_path).delete_prefix('/') }.compact
    end

    def tag(type:, tag:, file_path:)
      @tags[type] ||= {}
      @tags[type][tag] ||= []
      @tags[type][tag] << file_path
    end

    # The underscored folders, like basics in docs/_basics/.
    def folders(file_path:)
      underscored(File.dirname(relative(file_path))).reject { number?(it) }
    end

    # The last underscored number in the path, like 1 in docs/_basics/_1-getting-started.md.
    def order(file_path:)
      underscored(relative(file_path)).select { number?(it) }.last&.then { Integer(it, exception: false) || Float(it) }
    end

    def underscored(path)
      path.split(SEGMENTS).select { it.start_with?('_') }.map { it.delete_prefix('_') }
    end

    def relative(file_path)
      File.expand_path(file_path).delete_prefix(File.expand_path(@root))
    end

    def number?(string)
      !Float(string, exception: false).nil?
    end

    # Files with an order come first, by order, then the rest by path.
    def sort_key(file_path)
      order = @metadata[file_path][:order]
      [order.is_a?(Numeric) ? 0 : 1, order.is_a?(Numeric) ? order : 0, @metadata[file_path][:path].to_s]
    end
  end
end
