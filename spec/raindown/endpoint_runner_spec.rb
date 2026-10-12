# frozen_string_literal: true

require 'raindown/endpoint_runner'

RSpec.describe Raindown::EndpointRunner do
  def format(content, **options)
    described_class.format(content:, **options)
  end

  let(:curl) { "```sh\ncurl https://api.example.com/users\n```\n" }
  let(:response) { "```json\n{\n  \"id\": 1\n}\n```\n" }

  before do
    allow(Raindown::Curl).to receive(:run).and_return(["{\n  \"id\": 1\n}", 'json'])
  end

  it 'writes the response below the curl block when the directive has :x' do
    expect(format("<{ endpoint: :x }>\n\n#{curl}\nAfter.\n")).to eq("<{ endpoint: :x }>\n\n#{curl}\n#{response}\nAfter.\n")
  end

  it 'writes the response inside the closing tag' do
    expect(format("<{ endpoint: :x }>\n#{curl}<{ :endpoint }>\n")).to eq("<{ endpoint: :x }>\n#{curl}\n#{response}<{ :endpoint }>\n")
  end

  it 'accepts :execute' do
    expect(format("<{ endpoint: :execute }>\n\n#{curl}")).to eq("<{ endpoint: :execute }>\n\n#{curl}\n#{response}")
  end

  it 'does not run without :x' do
    content = "<{ endpoint: }>\n\n#{curl}"

    expect(format(content)).to eq(content)
    expect(Raindown::Curl).not_to have_received(:run)
  end

  it 'runs every endpoint when executing' do
    expect(format("<{ endpoint: }>\n\n#{curl}", execute: true)).to eq("<{ endpoint: }>\n\n#{curl}\n#{response}")
  end

  it 'fills an empty output block' do
    expect(format("<{ endpoint: :x }>\n\n#{curl}\n```\n```\n")).to eq("<{ endpoint: :x }>\n\n#{curl}\n#{response}")
  end

  it 'leaves existing output alone' do
    content = "<{ endpoint: :x }>\n\n#{curl}\n```json\n{}\n```\n"

    expect(format(content, execute: true)).to eq(content)
    expect(Raindown::Curl).not_to have_received(:run)
  end

  it 'ignores directives in code' do
    content = "````md\n<{ endpoint: :x }>\n\n#{curl}````\n"

    expect(format(content)).to eq(content)
  end

  it 'ignores a directive without a curl block below it' do
    content = "<{ endpoint: :x }>\n\n```sh\nls\n```\n"

    expect(format(content)).to eq(content)
  end

  it 'runs every endpoint in the file' do
    content = format("<{ endpoint: :x }>\n\n#{curl}\n<{ endpoint: :x }>\n\n#{curl}")

    expect(content.scan('```json').length).to eq(2)
  end

  it 'reads bare directives' do
    expect(format("endpoint: :x\n\n#{curl}", path: 'api.rd')).to eq("endpoint: :x\n\n#{curl}\n#{response}")
    expect(format("endpoint: :x\n\n#{curl}", path: 'api.md')).to eq("endpoint: :x\n\n#{curl}")
  end

  it 'fences the response with more backticks than it contains' do
    allow(Raindown::Curl).to receive(:run).and_return(["```\ncode\n```", 'text'])

    expect(format("<{ endpoint: :x }>\n\n#{curl}")).to end_with("\n````text\n```\ncode\n```\n````\n")
  end

  it 'warns and leaves the file alone when curl fails' do
    allow(Raindown::Curl).to receive(:run).and_raise(Raindown::Curl::Error, 'curl: (6) Could not resolve host')
    content = "<{ endpoint: :x }>\n\n#{curl}"

    expect { expect(format(content)).to eq(content) }.to output(/Endpoint failed: curl: \(6\)/).to_stderr
  end
end
