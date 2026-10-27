# frozen_string_literal: true

require 'raindown/tui/code_methods'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::CodeMethods do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  def write(name, content)
    File.join(@root, name).tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end

  def found = described_class.list(@root).map { [File.basename(it.path), it.label, it.line, it.lines.length] }

  describe 'without Universal Ctags' do
    before { allow(described_class).to receive(:tagged).and_return(nil) }

    it "finds functions by how they're indented, named after the class they're in, with their lines" do
      write('lib/shapes.rb', "module Shapes\n  class Square\n    def area = side * side\n\n" \
                             "    def draw\n      puts 'x'\n    end\n  end\nend\n")
      write('.raindown/sales.rb', "class Sales < Raindown::Chart\n  def points = []\nend\n")

      expect(found).to eq([['sales.rb', 'Sales#points', 2, 1], ['shapes.rb', 'Square#area', 3, 1], ['shapes.rb', 'Square#draw', 5, 3]])
    end

    it 'finds them in other languages too, like Python, JavaScript and Go' do
      write('app.py', "class Cart:\n    def total(self):\n        return 1\n\n    async def pay(self):\n        pass\n")
      write('web/cart.js', "export function render(cart) {\n  return cart\n}\n")
      write('main.go', "func (c *Cart) Total() int {\n\treturn 1\n}\n")

      expect(found).to eq([['app.py', 'Cart#total', 2, 2], ['app.py', 'Cart#pay', 5, 2], ['main.go', 'Total', 1, 3],
                           ['cart.js', 'render', 1, 3]])
    end

    it "leaves out specs, tests and the folders a project doesn't write, like vendor" do
      write('spec/shapes_spec.rb', "def helper = 1\n")
      write('vendor/gem.rb', "def vendored = 1\n")
      write('web/node_modules/lib.js', "function lib() {}\n")
      write('tool.rb', "def tool = 1\n")

      expect(found.map { it[1] }).to eq(['tool'])
    end
  end

  it 'finds them with Universal Ctags when it is installed' do
    write('lib/shapes.rb', "class Square\n  def area\n    1\n  end\nend\n")
    json = [{ _type: 'tag', name: 'Square', path: './lib/shapes.rb', line: 1, end: 5, kind: 'class' },
            { _type: 'tag', name: 'area', path: './lib/shapes.rb', line: 2, end: 4, kind: 'method', scope: 'Square' }]
    allow(Open3).to receive(:capture2).and_call_original
    allow(Open3).to receive(:capture2).with('ctags', any_args)
                                      .and_return([json.map(&:to_json).join("\n"), instance_double(Process::Status, success?: true)])

    expect(found).to eq([['shapes.rb', 'Square#area', 2, 3]])
  end

  it 'checksums its code, which changes with it, but not with its indent, trailing spaces or blank lines' do
    method = Raindown::TUI::CodeMethod.new(path: 'a.rb', owner: nil, name: 'area', line: 1, lines: ['def area', '  1', 'end'], changes: 0,
                                           drift: 0)

    expect(method.with(lines: ['    def area  ', '', '      1', '    end']).checksum).to eq(method.checksum)
    expect(method.with(lines: ['def area', '  2', 'end']).checksum).not_to eq(method.checksum)
  end

  it 'takes more cells for longer methods' do
    method = Raindown::TUI::CodeMethod.new(path: 'a.rb', owner: nil, name: 'long', line: 1, lines: ['x'] * 31, changes: 12, drift: 0)

    expect([method.size, method.with(lines: ['x']).size]).to eq([8, 1])
  end

  it "drifts from 0 to 9, by how it ranks among the project's methods by its lines times the commits to its file" do
    allow(described_class).to receive(:tagged).and_return(nil)
    write('a.rb', "def one = 1
def same = 1
def long
  1
  2
end
def longer
  1
  2
  3
  4
  5
end
")

    expect(described_class.list(@root).to_h { [it.name, it.drift] }).to eq('one' => 0, 'same' => 0, 'long' => 6, 'longer' => 9)
  end
end
