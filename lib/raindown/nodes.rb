# frozen_string_literal: true

module Raindown
  # Nodes are classes, usually LowNodes, that a node block writes into the Markdown and renders into the HTML.
  # A project keeps them in a .raindown folder, which is loaded with Dirload.
  # A node writes Markdown with #markdown, and HTML with #render if it has one.
  module Nodes
    FOLDER = '.raindown'
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

    # The node class a block names, when it's loaded and writes Markdown.
    def node_class(name)
      klass = Object.const_get(name)
      klass if klass.is_a?(Class) && klass.method_defined?(:markdown)
    rescue NameError
      nil
    end

    # One instance for each node and its props, kept for the whole process.
    # So a node can keep what its Markdown and HTML share, like a date, and both stay the same between renders.
    def instance(klass, props)
      key = [klass, props]
      instances[key] ||= begin
        id = list.length
        list << klass.new(**props)
        id
      end

      list[instances[key]]
    end

    def placeholder(node)
      "<!-- raindown:node #{list.index(node)} -->"
    end

    # Swaps each placeholder for its node's HTML.
    def render_placeholders(html)
      html.gsub(PLACEHOLDER) { html(list[::Regexp.last_match(1).to_i]) }
    end

    def html(node)
      return node.render_template(props: {}).to_s if node.class.respond_to?(:template) && node.class.template

      node.render.to_s
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
