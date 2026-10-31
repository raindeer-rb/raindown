# frozen_string_literal: true

require 'raindown/tui/feelings/kept_log'
require 'raindown/tui/feelings/code_methods'
require 'tmpdir'

RSpec.describe Raindown::TUI::KeptLog do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  let(:log) { described_class.new(root: @root) }
  let(:method) do
    Raindown::TUI::CodeMethod.new(path: File.join(@root, 'lib', 'report.rb'), owner: 'Report', name: 'summary', line: 5,
                                  lines: ['def summary(endpoint)', '  endpoint.url', 'end'], changes: 0, drift: 0, envy: nil)
  end

  it "notes down in .raindown/kept.csv that a method is kept, with its code's checksum, wherever its line moves" do
    log.dismiss(method)
    log.dismiss(method)

    expect(log.rows.map { it.values_at(:location, :method, :checksum) }).to eq([['lib/report.rb:5', 'Report#summary', method.checksum]])
    expect([log.dismissed?(method.with(line: 9)), log.dismissed?(method.with(name: 'other'))]).to eq([true, false])
  end

  it 'can envy again once its code changes, and forgets it then' do
    log.dismiss(method)
    changed = method.with(lines: ['def summary(endpoint)', '  endpoint.host', 'end'])
    expect(log.dismissed?(changed)).to be(false)

    log.forget_changed([method])
    expect(log.rows.length).to eq(1)
    log.forget_changed([changed])
    expect(described_class.new(root: @root).rows).to be_empty
  end
end
