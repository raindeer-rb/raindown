# frozen_string_literal: true

require 'raindown'
require 'raindown/cli'
require 'tmpdir'

RSpec.describe Raindown::Pages do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = dir
      example.run
    end
  end

  def write(path, content)
    file_path = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, content)
  end

  def pages
    described_class.load(root: @root)
  end

  def pages_metadata
    file_types = Dirload.file_paths(absolute_path: @root).group_by { Dirload.extension(file_path: it) }
    Dirload::Metadata.new(loaded_paths: {}, missed_paths: [], file_types:)
  end

  describe '#list' do
    before do
      write('docs/_basics/_2-setup.md', "---\ntitle: Setup\ntags: [ruby]\n---\n\n# Setup\n")
      write('docs/_basics/_1-getting-started.md', "---\ntitle: Getting started\ntags: [ruby, intro]\ndate: 2024-01-02\n---\n\nHi.\n")
      write('docs/_basics/extras.md', "---\ntitle: Extras\n---\n")
      write('docs/_1&_guides/deploy.rd', "# Deploy\n")
      write('docs/notes.txt', 'Not a page')
    end

    it 'lists the files in an underscored folder, by order and then path' do
      expect(pages.list(folder: 'basics').map(&:title)).to eq(['Getting started', 'Setup', 'Extras'])
    end

    it 'tags files with each item of their front matter' do
      expect(pages.list(tags: 'intro').map(&:title)).to eq(['Getting started'])
      expect(pages.list(tags: 'ruby').map(&:title)).to eq(['Getting started', 'Setup'])
    end

    it 'gives each file its front matter, folder, order, path from the root and content' do
      page = pages.list(folder: 'basics').first

      expect([page.title, page.folder, page.order, page.path, page.date])
        .to eq(['Getting started', 'basics', 1, 'docs/_basics/_1-getting-started.md', Date.new(2024, 1, 2)])
      expect(page.content).to eq("<p>Hi.</p>\n")
      expect(page.missing).to be_nil
    end

    it 'renders content with the render options, and bare directives in Raindown files' do
      write('docs/_basics/_3-toc.rd', "---\ntitle: TOC\n---\n\n# TOC\n\n:toc\n")
      hiding = described_class.new(metadata: pages_metadata, root: @root, render_options: { hide_directives: true })
      shown = pages.list(folder: 'basics').find { it.title == 'TOC' }.content
      hidden = hiding.list(folder: 'basics').find { it.title == 'TOC' }.content

      expect(shown).to include('<p><strong>:toc</strong></p>', 'Table of contents')
      expect(hidden).to include('<!-- :toc -->', 'Table of contents')
    end

    it 'reads folder tags joined by &' do
      expect(pages.list(folder: 'guides').map(&:path)).to eq(['docs/_1&_guides/deploy.rd'])
    end

    it 'lists every Markdown file without tags' do
      expect(pages.list.length).to eq(4)
    end
  end

  describe '.for' do
    it 'loads the files under the folder with .raindown, or else the file\'s folder' do
      write('.raindown/.keep', '')
      write('docs/_basics/a.md', "# A\n")
      write('other.md', "# Other\n")

      expect(described_class.for(File.join(@root, 'docs', 'index.rd')).list.length).to eq(2)
      expect(described_class.for(File.join(Dir.tmpdir, 'no-project', 'index.rd')).list).to eq([])
    end
  end

  it 'gives files: and list: their metadata from the CLI' do
    write('docs/_basics/_1-a.md', "---\ntitle: A\n---\n")
    write('index.rd', "files: folder: 'basics'\n\nlist: page folder: 'basics'\n## {page.title}\n")
    path = File.join(@root, 'index.rd')

    Raindown::CLI.run([path, '--once', '-o', File.join(@root, 'index.html')])

    expect(File.read(path)).to start_with("files: folder: 'basics'\n- [A](docs/_basics/_1-a.md)\n")
    expect(File.read(File.join(@root, 'index.html'))).to include('<a href="docs/_basics/_1-a.md">A</a>', '<h2 id="a">A')
  end
end
