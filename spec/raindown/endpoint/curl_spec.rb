# frozen_string_literal: true

require 'raindown/endpoint/curl'

RSpec.describe Raindown::Curl do
  describe '.request' do
    it "reads a snippet's method and URL, which is a POST when it sends data, as with curl" do
      expect(described_class.request('curl https://httpbin.org/uuid')).to eq(described_class::Request.new(method: 'GET', url: 'https://httpbin.org/uuid'))
      expect(described_class.request('curl -sSL -XDELETE https://a.io/x')).to eq(described_class::Request.new(method: 'DELETE', url: 'https://a.io/x'))
      expect(described_class.request("curl -d 'a=1' https://a.io/p")).to eq(described_class::Request.new(method: 'POST', url: 'https://a.io/p'))
      expect(described_class.request('curl -I https://a.io')).to eq(described_class::Request.new(method: 'HEAD', url: 'https://a.io'))
    end

    it "is nil for a snippet that isn't a curl request" do
      expect(described_class.request('ls')).to be_nil
      expect(described_class.request('curl -o out https://a.io')).to be_nil
    end
  end

  describe '.arguments' do
    it 'splits the snippet like a shell would, without curl, and spells options long' do
      snippet = "curl -X POST https://api.example.com/users \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"name\": \"rain\"}'\n"

      expect(described_class.arguments(snippet)).to eq(
        ['--request', 'POST', 'https://api.example.com/users', '--header', 'Content-Type: application/json',
         '--data', '{"name": "rain"}']
      )
    end

    it 'expands grouped short flags and attached values' do
      expect(described_class.arguments('curl -sSL -XPUT https://api.example.com'))
        .to eq(['--silent', '--show-error', '--location', '--request', 'PUT', 'https://api.example.com'])
    end

    it 'allows request options' do
      snippet = "curl --json '{}' --data-urlencode 'q=a@b' -u me:pw --compressed --url https://api.example.com"

      expect(described_class.arguments(snippet))
        .to eq(['--json', '{}', '--data-urlencode', 'q=a@b', '--user', 'me:pw', '--compressed', '--url', 'https://api.example.com'])
    end

    it 'rejects options that write, upload or load files' do
      ['-o out.json', '--output out.json', '-O', '-K evil.cfg', '--config evil.cfg', '-T secret', '-F file=@secret',
       '-b cookies.txt', '-c jar.txt', '-D headers.txt', '--trace log', '-sSo out.json'].each do |options|
        expect { described_class.arguments("curl #{options} https://api.example.com") }
          .to raise_error(described_class::Error, /isn't allowed/), options
      end
    end

    it 'rejects values that read a file' do
      ['-d @secret', '--data-binary @secret', '--json @secret', '-H @headers.txt', '--data-urlencode @secret',
       '--data-urlencode name@secret', '-d@secret'].each do |options|
        expect { described_class.arguments("curl #{options} https://api.example.com") }
          .to raise_error(described_class::Error, /can't read a file/), options
      end
    end

    it 'rejects URLs that are not http(s)' do
      ['file:///etc/passwd', 'ftp://example.com', '--url file:///etc/passwd', 'example.com'].each do |target|
        expect { described_class.arguments("curl #{target}") }.to raise_error(described_class::Error, /http\(s\) URLs/), target
      end
    end

    it 'rejects snippets without a URL' do
      expect { described_class.arguments('curl -s') }.to raise_error(described_class::Error, /need a URL/)
    end

    it 'rejects options missing their value' do
      expect { described_class.arguments('curl https://api.example.com -X') }.to raise_error(described_class::Error, /needs a value/)
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
      expect(Open3).to have_received(:capture3).with('curl', *described_class::SAFE_OPTIONS, '--silent', '--show-error', '--max-time', '30',
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
