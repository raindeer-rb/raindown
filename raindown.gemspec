# frozen_string_literal: true

require_relative 'lib/version'

Gem::Specification.new do |spec|
  spec.name = 'raindown'
  spec.version = Raindown::VERSION
  spec.authors = ['maedi']
  spec.email = ['maediprichard@gmail.com']

  spec.summary = 'Markup your markdown with a template and annotation layer'
  spec.description = <<~TEXT
    Raindown is a templating layer for static site generation
    and an annotation framework for Markdown files.
  TEXT

  spec.homepage = 'https://github.com/raindeer-rb/raindown'
  spec.required_ruby_version = '>= 3.3.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/raindeer-rb/raindown/src/branch/main'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir.glob('lib/**/*')
  end

  spec.require_paths = ['lib']
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }

  spec.add_dependency 'antlers'
  spec.add_dependency 'commonmarker'
  spec.add_dependency 'plugs'
end
