# frozen_string_literal: true

require 'raindown'
require 'raindown/nodes'

RSpec.describe Raindown::Stat do
  let(:issues) do
    Class.new(described_class) do
      def value(**) = 12
      def label = 'open issues'
    end
  end

  it 'draws its value in block digits above its label, as a card shows it, and writes them as code' do
    expect(issues.new.card_lines).to eq(['▀█  ▀▀█', ' █  █▀▀', '▀▀▀ ▀▀▀', 'open issues'])
    expect(issues.new.replace).to eq("```\n▀█  ▀▀█\n █  █▀▀\n▀▀▀ ▀▀▀\nopen issues\n```")
  end

  it "writes the value its own way, with a sign or a point on the digits' baseline, other characters on the middle line" do
    signed = Class.new(issues) { def number(value) = format('%+d%%', value) }

    expect(signed.new.card_lines.first(3)).to eq([' ▄  ▀█  ▀▀█', '▀█▀  █  █▀▀ %', '    ▀▀▀ ▀▀▀'])

    decimal = Class.new(issues) { def number(_value) = '0.5' }
    expect(decimal.new.card_lines.first(3)).to eq(['█▀█   █▀▀', '█ █   ▀▀█', '▀▀▀ ▀ ▀▀▀'])
  end

  it 'needs a value' do
    expect { Class.new(described_class).new.card_lines }.to raise_error(NotImplementedError)
  end
end
