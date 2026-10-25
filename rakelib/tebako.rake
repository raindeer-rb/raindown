# frozen_string_literal: true

require 'fileutils'
require 'rbconfig'
require_relative '../lib/version'

# Packages raindown and a Ruby runtime into one executable for the current platform.
# Tebako can't cross-compile, so each platform's binary is built on that platform (see .github/workflows/release.yml).
#
# Tebako only packages Gemfile apps (a .gemspec in the root is an unsupported scenario), so the gem is staged in a
# subfolder and depended on by path:
#
#   tmp/tebako/root/
#     Gemfile, Gemfile.lock  gem 'raindown', path: 'raindown', without the development group
#     bin/raindown           the entry point
#     raindown/              the gem: raindown.gemspec, lib/, bin/
module TebakoBuild
  RUBY_VERSION = '3.4.10'
  # Tebako 2.8.27 defaults to runtime 0.16.23, whose packages can't boot on macOS (tamatebako/tebako#738).
  RUNTIME_VERSION = '0.16.32'
  ROOT = 'tmp/tebako/root'
  GEM_DIR = "#{ROOT}/raindown".freeze
  GEM_FILES = ['bin/raindown', 'lib/', 'raindown.gemspec'].freeze

  # Gems are installed in the package for Ruby's ABI version, which is 3.4.0 for every Ruby 3.4.
  GEMS_DIR = "lib/ruby/gems/#{RUBY_VERSION.sub(/\.\d+\z/, '.0')}".freeze
  # Precompiled native gems like commonmarker ship a build for each Ruby, of which the package only runs one.
  OTHER_RUBIES = %w[3.1 3.2 3.3 3.4 3.5 4.0 4.1] - [RUBY_VERSION[/\A\d+\.\d+/]]
  # Files in the package that are never loaded: about a fifth of the binary.
  EXCLUDES = [
    "#{GEMS_DIR}/cache/*.gem", # The gem archives, kept after the gems are installed.
    *OTHER_RUBIES.map { "#{GEMS_DIR}/gems/*/lib/*/#{it}" },
    *%w[ext spec test].map { "#{GEMS_DIR}/gems/*/#{it}" } # Native sources (compiled into lib) and tests.
  ].freeze

  module_function

  def stage
    FileUtils.rm_rf(ROOT)

    source_files.each do |file|
      FileUtils.mkdir_p(File.join(GEM_DIR, File.dirname(file)))
      FileUtils.cp(file, File.join(GEM_DIR, file))
    end

    FileUtils.mkdir_p("#{ROOT}/bin")
    File.write("#{ROOT}/bin/raindown", ENTRY_POINT)

    stage_bundle
  end

  # Bundler can't set up inside a package yet: it chdirs into path and git gems, and chdir into the package fails
  # (tamatebako/tebako#734, fixed after 2.8.27). The gems are already installed, so put the path gem (raindown) on the
  # load path and let RubyGems load the rest.
  ENTRY_POINT = <<~RUBY
    #!/usr/bin/env ruby
    # frozen_string_literal: true

    $LOAD_PATH.unshift(File.expand_path('../raindown/lib', __dir__))

    require 'raindown/cli'

    Raindown::CLI.run(ARGV)
  RUBY

  # Keep the locked versions and platforms, but point at the staged gem and leave out development gems.
  def stage_bundle
    gemfile = File.read('Gemfile').sub(/^gemspec$/, "gem 'raindown', path: 'raindown'")
                  .sub(/^group :development do\n.*?^end\n/m, '')
    File.write("#{ROOT}/Gemfile", gemfile)
    FileUtils.cp('Gemfile.lock', "#{ROOT}/Gemfile.lock")

    Bundler.with_unbundled_env do
      system({ 'BUNDLE_GEMFILE' => File.expand_path("#{ROOT}/Gemfile") }, 'bundle', 'lock', exception: true)
    end
  end

  # Tracked and new (but not ignored) files, so uncommitted work is packaged too.
  def source_files
    `git ls-files --cached --others --exclude-standard`.lines(chomp: true).select do |file|
      GEM_FILES.any? { |path| path.end_with?('/') ? file.start_with?(path) : file == path } && File.file?(file)
    end
  end

  # Tebako adds .exe to the output on Windows.
  def output
    "pkg/raindown-#{Raindown::VERSION}-#{ENV.fetch('TEBAKO_PLATFORM', platform)}"
  end

  def platform
    os = RbConfig::CONFIG['host_os']
    arch = RbConfig::CONFIG['host_cpu'].sub('aarch64', 'arm64')

    case os
    when /darwin/ then "macos-#{arch}"
    when /linux-musl/ then "linux-musl-#{arch}"
    when /linux/ then "linux-#{arch}"
    when /mingw|mswin/ then "windows-#{arch}"
    else raise "Unsupported platform for tebako: #{os}"
    end
  end
end

desc 'Build a standalone raindown executable for this platform with tebako'
task :tebako do
  TebakoBuild.stage
  FileUtils.mkdir_p('pkg')

  sh ENV.fetch('TEBAKO', 'tebako'), 'press',
     '--root', TebakoBuild::ROOT,
     '--entry-point', 'bin/raindown',
     '--Ruby', TebakoBuild::RUBY_VERSION,
     '--tebako-version', TebakoBuild::RUNTIME_VERSION,
     '--mode', 'self-contained',
     '--quiet-notices',
     *TebakoBuild::EXCLUDES.flat_map { ['--exclude', it] },
     '--output', TebakoBuild.output
end
