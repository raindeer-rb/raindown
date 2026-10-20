# frozen_string_literal: true

require 'yaml'

module Raindown
  # A project's settings, from config.yml in its .raindown folder:
  #   hide_directives: true    # Directives become HTML comments rather than bold text in the HTML.
  #   highlight_code: false    # Code blocks aren't highlighted, so the browser can highlight them instead.
  module Config
    FILE = 'config.yml'
    DEFAULTS = { hide_directives: false, highlight_code: true }.freeze

    module_function

    # The settings for the project a file is in, or the defaults outside one.
    def for(path)
      folder = Nodes.find_folder(File.dirname(File.expand_path(path)))
      file = folder && File.join(folder, FILE)
      return DEFAULTS unless file && File.exist?(file)

      DEFAULTS.merge(YAML.safe_load_file(file, symbolize_names: true) || {})
    end

    # The settings for rendering a file, like Raindown.render(**Config.render_options(path)).
    def render_options(path)
      self.for(path).slice(:hide_directives, :highlight_code)
    end
  end
end
