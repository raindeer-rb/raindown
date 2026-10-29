# frozen_string_literal: true

require 'raindown/tui/project'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::Workers do
  subject(:workers) { Raindown::TUI::Project.workers(root: @dir) }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = File.realpath(dir)
      example.run
    ensure
      workers.stop
    end
  end

  # A project with a WorkersShout node and a WorkersSales chart, which have the same names in each project but differ.
  def project(name, shout:, sales:)
    root = File.join(@dir, name)
    FileUtils.mkdir_p(File.join(root, '.raindown'))
    node(root, shout)
    File.write(File.join(root, '.raindown', 'sales.rb'),
               "class WorkersSales < Raindown::Chart\n  def initialize(**) = super('#{sales}', **)\nend\n")
    File.join(root, 'notes.rd').tap { File.write(it, "# Notes\n\nWorkersShout:\n\nWorkersSales:\n") }
  end

  def node(root, shout)
    File.write(File.join(root, '.raindown', 'shout.rb'), "class WorkersShout < Raindown::Node\n  def replace = '#{shout}'\nend\n")
  end

  it "sends a file's requests to the worker of the project it's in, the nearest one above it" do
    raindeer = project('raindeer', shout: 'Deer', sales: '1 2 3')
    FileUtils.mkdir_p(File.join(@dir, 'raindeer', 'docs', '.raindown'))

    expect(workers.for(raindeer).root).to eq(File.join(@dir, 'raindeer'))
    expect(workers.for(File.join(@dir, 'raindeer', 'docs', 'a.md')).root).to eq(File.join(@dir, 'raindeer', 'docs'))
    expect(workers.for(File.join(@dir, 'plain.md')).root).to eq(@dir)
  end

  context 'with fork', fork: true, if: Process.respond_to?(:fork) do
    let(:raindeer) { project('raindeer', shout: 'Deer to be different', sales: '1 2 3') }
    let(:raindown) { project('raindown', shout: 'Stay sane out there', sales: '3 2 1') }

    it "answers with each project's own nodes, even when their names are the same, without loading them here" do
      [raindeer, raindown].each { workers.for(it).call(:write_back, it) }

      expect(File.read(raindeer)).to include("WorkersShout:\nDeer to be different\n")
      expect(File.read(raindown)).to include("WorkersShout:\nStay sane out there\n")
      expect(workers.each.map { it.call(:charts)[:cards].map(&:chart) }.reject(&:empty?)).to eq([[['▁▅█']], [['█▅▁']]])
      expect(workers.for(raindeer).call(:outline, raindeer).directives.map(&:name)).to eq(%w[WorkersShout WorkersSales])
      expect(defined?(WorkersShout)).to be_nil
    end

    it "loads a project's nodes again once it's restarted" do
      workers.for(raindeer).call(:write_back, raindeer)
      node(File.join(@dir, 'raindeer'), 'New')

      workers.restart
      workers.for(raindeer).call(:write_back, raindeer)
      expect(File.read(raindeer)).to include("WorkersShout:\nNew\n")
    end

    it "raises a project's errors, and starts a worker that stopped again" do
      expect { workers.for(raindeer).call(:outline, File.join(@dir, 'missing.md')) }
        .to raise_error(Raindown::Workers::Worker::Error, /No such file/)

      worker = workers.for(raindeer)
      worker.call(:charts)
      Process.kill('KILL', worker.instance_variable_get(:@pid))
      Process.wait(worker.instance_variable_get(:@pid)) rescue Errno::ECHILD # rubocop:disable Style/RescueModifier

      expect(worker.call(:charts)[:cards].length).to eq(1)
    end
  end
end
