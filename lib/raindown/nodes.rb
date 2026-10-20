# frozen_string_literal: true

require_relative 'files'
require_relative 'node'
require_relative 'toc'

module Raindown
  # Nodes are LowNodes that a node block writes into the Markdown and renders into the HTML.
  # A project keeps them in a .raindown folder, which is loaded with Dirload.
  # A node writes Markdown with #replace, and HTML with #render if it has one. Either can take the keywords
  # document: (the Markdown being rendered), metadata: and bare:, and gets the ones it asks for.
  module Nodes
    FOLDER = '.raindown'
    # Lowercase directives for Raindown's own nodes. A project's own TOC or Files node replaces Raindown's.
    BUILT_INS = { 'toc' => 'TOC', 'files' => 'Files' }.freeze
    # A placeholder for a node's HTML, which stays as it is through Commonmarker and Antlers.
    PLACEHOLDER = /<!-- raindown:node (\d+) -->/

    module_function

    # Loads the .raindown folder beside the file or in the nearest directory above it, once per process.
    def load(path)
      folder = find_folder(File.dirname(File.expand_path(path)))
      return if folder.nil? || loaded.include?(folder)

      require 'lownode'
      require 'dirload'
      loaded << folder
      dirload(folder)
    end

    def find_folder(directory)
      loop do
        folder = File.join(directory, FOLDER)
        return folder if File.directory?(folder)

        parent = File.dirname(directory)
        return if parent == directory

        directory = parent
      end
    end

    def loaded
      @loaded ||= []
    end

    # The node class a block names, when it's loaded.
    def node_class(name)
      return loaded_class(name) unless BUILT_INS.key?(name)

      loaded_class(BUILT_INS[name]) || Raindown.const_get(BUILT_INS[name])
    end

    def loaded_class(name)
      klass = Object.const_get(name)
      klass if node?(klass)
    rescue NameError
      nil
    end

    # A LowNode, or one of Raindown's own nodes, that writes Markdown. In an app, LowNodes are also routes and pages,
    # which don't have replace, so text like "Note:" only starts a block when the Note node writes something.
    def node?(klass)
      return false unless klass.is_a?(Class) && klass.method_defined?(:replace)

      klass < Node || (defined?(::LowNode) && klass < ::LowNode) || false
    end

    # Calls a node's replace or render with the context keywords it takes.
    def call(node, name, **context)
      parameters = node.method(name).parameters
      return node.public_send(name, **context) if parameters.any? { |type, _| type == :keyrest }

      keys = parameters.filter_map { |type, key| key if %i[key keyreq].include?(type) }
      node.public_send(name, **context.slice(*keys))
    end

    # One instance for each node and its props, kept for the whole process.
    # So a node can keep what its Markdown and HTML share, like a date, and both stay the same between renders.
    def instance(klass, props, args = [])
      key = [klass, args, props]
      instances[key] ||= begin
        id = list.length
        list << klass.new(*args, **props)
        id
      end

      list[instances[key]]
    end

    def placeholder(node)
      "<!-- raindown:node #{list.index(node)} -->"
    end

    # Swaps each placeholder for its node's HTML.
    def render_placeholders(html, **context)
      html.gsub(PLACEHOLDER) { html(list[::Regexp.last_match(1).to_i], **context) }
    end

    def html(node, **context)
      return node.render_template(props: {}).to_s if node.class.respond_to?(:template) && node.class.template

      call(node, :render, **context).to_s
    end

    # Whether the node renders its own HTML rather than the HTML of its Markdown.
    def html?(node)
      node.respond_to?(:render) || (node.class.respond_to?(:template) && !node.class.template.nil?)
    end

    def instances
      @instances ||= {}
    end

    def list
      @list ||= []
    end
  end
end
