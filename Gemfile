# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in dependency.gemspec
gemspec

group :development do
  local_gems = {
    'dirload' => '../dirload',
    'lowevent' => '../lowevent',
    'lowkey' => '../lowkey',
    'lowloop' => '../lowloop',
    'lownode' => '../lownode',

    'antlers' => '../antlers',
    'expressions' => '../expressions',
    'observers' => '../observers',
    'plugs' => '../plugs',
    'providers' => '../providers',
    'trees' => '../trees'
  }

  local_gems.each do |name, relative_path|
    if File.exist?(File.expand_path(relative_path, __dir__))
      gem name, path: relative_path
    else
      gem name
    end
  end

  gem 'irb'
  gem 'rake'
  gem 'rspec'
  gem 'rubocop'
end
