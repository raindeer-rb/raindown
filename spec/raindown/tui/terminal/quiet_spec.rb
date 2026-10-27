# frozen_string_literal: true

require 'raindown/tui/terminal/quiet'

RSpec.describe Raindown::TUI::Quiet do
  describe '.holding_stderr' do
    it 'writes what was written to stderr once the block is done, rather than over the screen' do
      written = []

      expect do
        described_class.holding_stderr do
          warn 'Endpoint failed'
          written << $stderr.string
        end
      end.to output("Endpoint failed\n").to_stderr
      expect(written).to eq(["Endpoint failed\n"])
    end
  end

  describe '.quietly' do
    it "doesn't warn while the block runs" do
      expect { described_class.quietly { warn 'Undefining the allocator' } }.not_to output.to_stderr
      expect($VERBOSE).not_to be_nil
    end
  end
end
