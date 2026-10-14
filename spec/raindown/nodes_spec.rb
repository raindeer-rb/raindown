# frozen_string_literal: true

require 'raindown'
require 'helpers/nodes'
require 'tmpdir'

RSpec.describe Raindown::Nodes do
  describe '.find_folder' do
    it 'finds the .raindown folder beside a file or above it' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, '.raindown'))
        FileUtils.mkdir_p(File.join(dir, 'docs', 'deep'))

        expect(described_class.find_folder(File.join(dir, 'docs', 'deep'))).to eq(File.join(dir, '.raindown'))
      end
    end
  end

  describe '.load' do
    it 'loads the nodes in the .raindown folder once' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, '.raindown'))
        File.write(File.join(dir, '.raindown', 'spec_loaded.rb'), "class SpecLoaded < LowNode\n  def markdown = 'Loaded'\nend\n")

        2.times { described_class.load(File.join(dir, 'notes.rd')) }

        expect(described_class.node_class('SpecLoaded')).to eq(SpecLoaded)
        expect(SpecLoaded.ancestors).to include(LowNode)
        expect(described_class.loaded.count { |folder| folder.start_with?(dir) }).to eq(1)
      end
    end
  end

  describe '.node_class' do
    it 'is a loaded class that writes Markdown' do
      expect(described_class.node_class('SpecReleases')).to eq(SpecReleases)
      expect([described_class.node_class('String'), described_class.node_class('Missing')]).to all(be_nil)
    end
  end

  describe '.instance' do
    it 'keeps one instance for each node and props' do
      expect(described_class.instance(SpecReleases, { limit: 9 })).to be(described_class.instance(SpecReleases, { limit: 9 }))
    end
  end

  describe '.render_placeholders' do
    it 'renders the same instance each time' do
      node = described_class.instance(SpecReleases, { limit: 1 })
      html = described_class.placeholder(node)

      expect(described_class.render_placeholders(html)).to eq('<ol data-count="1"><li>1.2.0</li></ol>')
      expect(described_class.render_placeholders(html)).to eq('<ol data-count="2"><li>1.2.0</li></ol>')
    end
  end
end
