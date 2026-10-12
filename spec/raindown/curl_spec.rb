# frozen_string_literal: true

require 'raindown/curl'

RSpec.describe Raindown::Curl do
  describe '.arguments' do
    it 'splits the snippet like a shell would, without curl' do
      snippet = "curl -X POST https://api.example.com/users \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"name\": \"rain\"}'\n"

      expect(described_class.arguments(snippet))
        .to eq(['-X', 'POST', 'https://api.example.com/users', '-H', 'Content-Type: application/json', '-d', '{"name": "rain"}'])
    end

    it 'drops a leading prompt' do
      expect(described_class.arguments('$ curl https://api.example.com')).to eq(['https://api.example.com'])
    end

    it 'rejects snippets that are not curl' do
      expect { described_class.arguments('wget https://api.example.com') }.to raise_error(described_class::Error, /start with curl/)
    end

    it 'rejects pipes and other shell operators' do
      expect { described_class.arguments('curl https://api.example.com | jq') }.to raise_error(described_class::Error, /single curl/)
      expect { described_class.arguments('curl https://api.example.com > out.json') }.to raise_error(described_class::Error)
    end

    it 'rejects unbalanced quotes' do
      expect { described_class.arguments("curl -d '{") }.to raise_error(described_class::Error, /Can't read/)
    end
  end

  describe '.run' do
    def stub_curl(stdout, success: true, stderr: '')
      status = instance_double(Process::Status, success?: success, exitstatus: success ? 0 : 6)
      allow(Open3).to receive(:capture3).and_return([stdout, stderr, status])
    end

    it 'runs curl without a shell and returns pretty JSON' do
      stub_curl("{\"id\":1}#{described_class::TYPE_MARKER}application/json; charset=utf-8")

      expect(described_class.run('curl https://api.example.com')).to eq(["{\n  \"id\": 1\n}", 'json'])
      expect(Open3).to have_received(:capture3).with('curl', '--silent', '--show-error', '--max-time', '30',
                                                     'https://api.example.com', '--write-out', anything)
    end

    it 'keeps other bodies as they are' do
      stub_curl("<p>Hi</p>#{described_class::TYPE_MARKER}text/html")

      expect(described_class.run('curl https://example.com')).to eq(['<p>Hi</p>', 'html'])
    end

    it 'has no language for unknown content types' do
      stub_curl("bytes#{described_class::TYPE_MARKER}application/octet-stream")

      expect(described_class.run('curl https://example.com').last).to eq('')
    end

    it 'raises with curl\'s error when the request fails' do
      stub_curl('', success: false, stderr: "curl: (6) Could not resolve host: x\n")

      expect { described_class.run('curl https://x') }.to raise_error(described_class::Error, 'curl: (6) Could not resolve host: x')
    end

    it 'raises when curl is not installed' do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

      expect { described_class.run('curl https://x') }.to raise_error(described_class::Error, 'curl is not installed')
    end
  end
end
