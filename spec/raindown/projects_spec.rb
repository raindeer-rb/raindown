# frozen_string_literal: true

require 'raindown/projects'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::Projects do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = File.realpath(dir)
      example.run
    end
  end

  def project(path)
    File.join(@dir, path).tap { FileUtils.mkdir_p(File.join(it, '.raindown')) }
  end

  describe '.roots' do
    it 'finds the projects below a directory, including projects inside projects' do
      docs = project('docs')
      guides = project('docs/guides')
      FileUtils.mkdir_p(File.join(@dir, 'plain'))

      expect(described_class.roots(@dir)).to contain_exactly(docs, guides)
    end

    it 'finds the project the directory is in' do
      docs = project('docs')
      FileUtils.mkdir_p(File.join(docs, 'pages'))

      expect(described_class.roots(File.join(docs, 'pages'))).to eq([docs])
    end

    it 'skips dependency, build and hidden folders' do
      %w[node_modules/pkg vendor/gem build/site .cache/x].each { project(it) }

      expect(described_class.roots(@dir)).to be_empty
    end
  end

  describe '.root' do
    it 'is the nearest project above a file' do
      docs = project('docs')
      guides = project('docs/guides')

      expect(described_class.root(File.join(docs, 'a.md'))).to eq(docs)
      expect(described_class.root(File.join(guides, 'deep', 'b.md'))).to eq(guides)
      expect(described_class.root(File.join(@dir, 'c.md'))).to be_nil
    end
  end

  describe '.files' do
    it "lists the project's Markdown files, leaving out ignored folders and the projects inside it" do
      root = project('docs')
      %w[a.md sub/b.rd node_modules/c.md .github/d.md notes.txt].each do |file|
        FileUtils.mkdir_p(File.dirname(File.join(root, file)))
        File.write(File.join(root, file), '')
      end
      File.write(File.join(project('docs/guides'), 'e.md'), '')

      expect(described_class.files(root)).to eq([File.join(root, 'a.md'), File.join(root, 'sub', 'b.rd')])
    end

    it 'lists the files of the projects inside it when asked' do
      root = project('docs')
      File.write(File.join(root, 'a.md'), '')
      File.write(File.join(project('docs/guides'), 'b.md'), '')

      expect(described_class.files(root, nested: true)).to eq([File.join(root, 'a.md'), File.join(root, 'guides', 'b.md')])
    end
  end

  describe '.markdown?' do
    it 'is true for Markdown and Raindown files in the project, but not in its ignored folders' do
      root = project('docs')

      expect(%w[a.md b.rd c.markdown d.raindown sub/e.md].map { described_class.markdown?(File.join(root, it), root:) })
        .to all(be(true))
      expect(%w[a.txt node_modules/a.md .github/a.md build/a.md].map { described_class.markdown?(File.join(root, it), root:) })
        .to all(be(false))
    end
  end

  describe '.node?' do
    it "is true for Ruby files in the project's .raindown folder" do
      root = project('docs')

      expect(described_class.node?(File.join(root, '.raindown', 'shout.rb'), root:)).to be(true)
      expect(described_class.node?(File.join(root, '.raindown', 'shout.rbx'), root:)).to be(true)
      expect(described_class.node?(File.join(root, '.raindown', 'config.yml'), root:)).to be(false)
      expect(described_class.node?(File.join(root, 'shout.rb'), root:)).to be(false)
    end
  end
end
