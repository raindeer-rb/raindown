# frozen_string_literal: true

require 'raindown/sketches'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::Sketches do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  let(:box) { "╭──────╮\n│ Idea │\n╰──────╯\n" }
  let(:reply) { "Here:\n\n```\n#{box}```\n\nand code:\n\n```ruby\nputs '─'\n```\n\n```\nplain text\n```\n\n```diagram\nA then B\n```\n" }

  # A transcript of Claude Code's, as JSON lines: what was typed, the replies to it, and a tool's result between them.
  def transcript(*entries)
    File.join(@root, 'transcript.jsonl').tap { |path| File.write(path, entries.map(&:to_json).join("\n")) }
  end

  def said(type, *content) = { type:, message: { role: type, content: } }
  def text(text) = { type: 'text', text: }
  def kind(drawing) = described_class.kind(drawing.lines(chomp: true))

  it 'keeps the code blocks that are drawn, or marked with a kind, each with its kind, but not other code or text' do
    expect(described_class.drawn(reply)).to eq([['mockup', box], ['diagram', "A then B\n"]])
  end

  it 'works out what a sketch is from what it is drawn with, the same each time' do
    flow = "╭─────╮     ╭─────╮\n│ CLI │ ──▶ │ TUI │\n╰─────╯     ╰─────╯\n"
    down = "╭─────╮\n╰──┬──╯\n   │\n   ▼\n Rewriter\n"
    screen = " Dashboard  │ RAINDOWN EXCHANGE\n Feelings   │ CLI  0.17  ▼ 0.33   ▆▅▃▂▁▁\n            │ DOCS 1.00  ▲ 0.83   ▁▁▁▃▆█\n"
    chart = "Jun  ██████▊      640\nJul  ████████▍    820\n"
    table = "name │ score\n─────┼──────\nCLI  │ 0.17\n"

    expect([flow, down, screen, chart, table].map { kind(it) }).to eq(%w[diagram diagram mockup chart table])
    expect([kind(screen), kind(screen)]).to eq(%w[mockup mockup])
  end

  it "reads the replies since the last thing typed, past tools' results, but not the replies before it" do
    path = transcript(said('user', 'first'), said('assistant', text('old ```')),
                      said('user', text('draw it')), said('assistant', text('Drawing.'), { type: 'tool_use', name: 'Bash' }),
                      said('user', { type: 'tool_result', content: 'ok' }), said('assistant', text('Done.')))

    expect(described_class.last_reply(path)).to eq("Drawing.\nDone.")
  end

  it "saves the last reply's sketches with their kinds to .raindown/sketches.md, and reads them back newest first" do
    FileUtils.mkdir_p(File.join(@root, '.raindown'))
    described_class.save('cwd' => @root, 'transcript_path' => transcript(said('user', 'draw'), said('assistant', text(reply))))
    described_class.save('cwd' => @root, 'transcript_path' => transcript(said('user', 'again'), said('assistant', text("```\n▁▃▅█\n```"))))

    sketches = described_class.read(@root)
    expect(sketches.map { [it.kind, it.lines] }).to eq([['chart', ['▁▃▅█']], ['diagram', ['A then B']], ['mockup', box.lines(chomp: true)]])
    expect(sketches.map(&:time)).to all(match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/))
    lines = File.readlines(File.join(@root, described_class::FILE), chomp: true)
    expect(sketches.map { lines[it.line - 1] }).to eq(['▁▃▅█', 'A then B', '╭──────╮'])
  end

  it 'saves nothing outside a project, or from a reply without sketches' do
    described_class.save('cwd' => @root, 'transcript_path' => transcript(said('user', 'hi'), said('assistant', text(reply))))
    FileUtils.mkdir_p(File.join(@root, '.raindown'))
    described_class.save('cwd' => @root, 'transcript_path' => transcript(said('user', 'hi'), said('assistant', text('No drawings.'))))

    expect(File.exist?(File.join(@root, described_class::FILE))).to be(false)
  end
end
