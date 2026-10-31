# frozen_string_literal: true

require 'raindown/tui/feelings/code_methods'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::TUI::Cuckoos do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  before { allow(Raindown::TUI::CodeMethods).to receive(:tagged).and_return(nil) }

  def write(name, content)
    File.join(@root, name).tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end

  def cuckoos = Raindown::TUI::CodeMethods.list(@root).to_h { [it.label, it.cuckoo] }
  def laid = cuckoos.select { |_, cuckoo| cuckoo.laid? }.transform_values(&:reason)

  # A method from its code, as Ctags would find it, in any language.
  def code_method(path, owner, name, code)
    Raindown::TUI::CodeMethod.new(path:, owner:, name:, line: 1, lines: code.lines(chomp: true), changes: 0, drift: 0, cuckoo: nil)
  end

  let(:endpoint) do
    <<~RUBY
      class Endpoint
        def url = [host, path].join('/')
        def host = 'example.com'
        def path = 'orders'
      end
    RUBY
  end

  it 'lays a Ruby method that mostly works with another class, by its parameter named after it, and says where it belongs' do
    write('lib/endpoint.rb', endpoint)
    write('lib/report.rb', <<~RUBY)
      class Report
        def heading = @title
        def title = heading.upcase

        def summary(endpoint)
          [endpoint.url, endpoint.host, endpoint.path, endpoint.verb].join(' ')
        end
      end
    RUBY

    expect(laid).to eq('Report#summary' => 'probably belongs to Endpoint: 4 calls on endpoint, 0 on self')
    expect(cuckoos['Report#summary'].then { [it.score, it.home] }).to eq([9, 'Endpoint'])
    expect(cuckoos.except('Report#summary').values.map(&:score).uniq).to eq([0])
  end

  it "doesn't lay a method that works with its own nest as well, a function outside a class, or one with a variable " \
     "named like a class that calls none of the class's methods" do
    write('lib/endpoint.rb', endpoint)
    write('lib/report.rb', <<~RUBY)
      class Report
        def heading = @title
        def title = heading.upcase

        def compare(endpoint)
          [endpoint.url, endpoint.host, endpoint.path, @title, heading, title]
        end

        def strip(text)
          endpoint = text.strip
          [endpoint.downcase, endpoint.upcase, endpoint.length]
        end
      end
    RUBY
    write('lib/helpers.rb', "def describe(endpoint)\n  [endpoint.url, endpoint.host, endpoint.path, endpoint.verb]\nend\n")

    expect(laid).to be_empty
    expect(cuckoos['describe'].evidence).to eq(0)
  end

  it 'lays one in Python too, by self and calls on the other class' do
    write('shop.py', <<~PYTHON)
      class Order:
          def total(self):
              return sum(self.items())

          def items(self):
              return []


      class Mailer:
          def send(self, to):
              return self.deliver(to)

          def deliver(self, to):
              return to

          def receipt(self, order):
              lines = order.items()
              return order.total() + order.discount + order.tax + len(lines)
    PYTHON

    expect(laid).to eq('Mailer#receipt' => 'probably belongs to Order: 4 calls on order, 0 on self')
  end

  it 'lays one in JavaScript too, by this, and in the same way however its methods are found' do
    methods = [
      code_method('web/order.js', 'Order', 'total', "total() {\n  return this.items().length\n}"),
      code_method('web/order.js', 'Order', 'items', "items() {\n  return this.lines\n}"),
      code_method('web/cart.js', 'Cart', 'add', "add(item) {\n  this.lines.push(item)\n  this.save()\n}"),
      code_method('web/cart.js', 'Cart', 'save', "save() {\n  localStorage.cart = JSON.stringify(this.lines)\n}"),
      code_method('web/cart.js', 'Cart', 'checkout', "checkout(order) {\n  const paid = order.total() > 0\n" \
                                                     "  return paid && order.items().every((item) => item.price) && order.ready\n}")
    ]
    cuckoo = described_class.laying(methods).last.cuckoo

    expect([cuckoo.laid?, cuckoo.reason]).to eq([true, 'probably belongs to Order: 3 calls on order, 0 on self'])
  end

  it "adds being named after another class it uses, and a loner's, and being in a class not named after its file" do
    write('lib/invoice.rb', "class Invoice\n  def number = 1\n  def total = number * 2\nend\n")
    write('lib/account.rb', <<~RUBY)
      class Account
        def name = @name
        def label = name.upcase
      end

      class Owner
        def initialize = @id = 1
        def id = @id

        def invoice_line(item)
          Invoice.new.number.to_s + item.to_s
        end
      end
    RUBY

    expect(laid).to eq('Owner#invoice_line' => "probably belongs to Invoice: it's named after it, and makes 0 calls on self")
    expect(cuckoos['Owner#invoice_line'].evidence).to eq(4)
  end

  it 'scores from 0 to 9 by how its evidence ranks among the project, the same for the same evidence' do
    methods = %w[a b c].map { code_method('a.rb', 'A', it, "def #{it}\n  @x\nend") } +
              [code_method('b.rb', 'B', 'lone', "def lone\n  1\nend")]

    expect(described_class.laying(methods).map { [it.cuckoo.score, it.cuckoo.evidence, it.cuckoo.laid?] })
      .to eq([[0, 0, false], [0, 0, false], [0, 0, false], [9, 1, false]])
  end
end
