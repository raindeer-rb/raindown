# frozen_string_literal: true

require 'yaml'

module Raindown
  # A project's settings, from config.yml in its .raindown folder:
  #   hide_directives: true    # Directives become HTML comments rather than bold text in the HTML.
  module Config
    FILE = 'config.yml'
    DEFAULTS = { hide_directives: false }.freeze

    module_function

    # The settings for the project a file is in, or the defaults outside one.
    def for(path)
      folder = Nodes.find_folder(File.dirname(File.expand_path(path)))
      file = folder && File.join(folder, FILE)
      return DEFAULTS unless file && File.exist?(file)

      DEFAULTS.merge(YAML.safe_load_file(file, symbolize_names: true) || {})
    end
  end
end
