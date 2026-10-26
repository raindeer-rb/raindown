# frozen_string_literal: true

require 'lowkey'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Prism takes about 0.4s to load in the standalone binary, so rendering only loads it when something needs parsing,
# like a project's nodes. Each render runs in its own Ruby, since the specs have already loaded Prism.
RSpec.describe 'Loading Prism' do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  before { skip 'needs a Lowkey that loads Prism lazily' unless Lowkey.respond_to?(:load_prism) }

  def render(file, content)
    path = File.join(@dir, file).tap { File.write(it, content) }
    script = <<~RUBY
      require 'raindown/cli'
      at_exit { $stderr.print(defined?(Prism::Node) ? 'Prism loaded' : 'Prism not loaded') }
      Raindown::CLI.run([#{path.inspect}, '--html'])
    RUBY
    html, prism, status = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-e', script)
    raise prism unless status.success?

    [html, prism]
  end

  it 'is not loaded to render plain Markdown' do
    html, prism = render('notes.md', "---\ntitle: Notes\n---\n\n# {title}\n\n<{ :toc }>\n\n## Setup\n")

    expect(html).to include('Table of contents')
    expect(prism).to eq('Prism not loaded')
  end

  it "is loaded to load a project's nodes" do
    FileUtils.mkdir_p(File.join(@dir, '.raindown'))
    File.write(File.join(@dir, '.raindown', 'shout.rb'), "class Shout < Raindown::Node\n  def replace = 'Loud'\nend\n")

    html, prism = render('notes.rd', "# Notes\n\nShout:\n")

    expect(html).to include('Loud')
    expect(prism).to eq('Prism loaded')
  end

  it 'is not loaded to read plain directive values' do
    skip 'needs a Lowkey that reads plain values without Prism' unless Lowkey::ValueParser.const_defined?(:PLAIN_VALUES)

    html, prism = render('notes.rd', "# Notes\n\nchart: '3 5 2 8' width: 10\n")

    expect(html).to include('▂')
    expect(prism).to eq('Prism not loaded')
  end
end
