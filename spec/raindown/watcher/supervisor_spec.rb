# frozen_string_literal: true

require 'raindown/watcher/supervisor'
require 'fileutils'
require 'tmpdir'

RSpec.describe Raindown::Watcher::Supervisor do
  subject(:supervisor) { described_class.new(directory: @dir) }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = File.realpath(dir)
      example.run
    ensure
      supervisor.stop
    end
  end

  # A project with a Shout node, whose output each project sets differently.
  def project(name, shout:)
    root = File.join(@dir, name)
    FileUtils.mkdir_p(File.join(root, '.raindown'))
    node(root, shout)
    File.join(root, 'notes.rd').tap { File.write(it, "# Notes\n\nShout:\n") }
  end

  def node(root, shout)
    File.write(File.join(root, '.raindown', 'shout.rb'), "class Shout < Raindown::Node\n  def replace = '#{shout}'\nend\n")
  end

  # Forked workers update files in the background.
  def eventually(timeout: 15)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    sleep 0.05 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    yield
  end

  context 'with fork', if: Process.respond_to?(:fork) do
    it "writes back with each project's own nodes, even when their names are the same" do
      raindeer = project('raindeer', shout: 'Deer to be different')
      raindown = project('raindown', shout: 'Stay sane out there')

      expect do
        supervisor.handle([raindeer, raindown])
        eventually { File.read(raindeer).include?('Deer') && File.read(raindown).include?('Stay sane') }
      end.to output(/(?=.*\[raindeer\] Updated notes\.rd)(?=.*\[raindown\] Updated notes\.rd)/m).to_stdout_from_any_process

      expect(File.read(raindeer)).to eq("# Notes\n\nShout:\nDeer to be different\n")
      expect(File.read(raindown)).to eq("# Notes\n\nShout:\nStay sane out there\n")
    end

    it "reloads a project's nodes when one of them changes" do
      raindeer = project('raindeer', shout: 'Old')
      expect do
        supervisor.handle([raindeer])
        eventually { File.read(raindeer).include?('Old') }
      end.to output.to_stdout_from_any_process

      node(File.join(@dir, 'raindeer'), 'New')
      expect do
        supervisor.handle([File.join(@dir, 'raindeer', '.raindown', 'shout.rb'), raindeer])
        eventually { File.read(raindeer).include?('New') }
      end.to output(/\[raindeer\] Reloading nodes/).to_stdout_from_any_process

      expect(File.read(raindeer)).to eq("# Notes\n\nShout:\nNew\n")
    end

    it "doesn't hold up a project while another's write-back is slow, like an endpoint's request" do
      slow = project('raindeer', shout: 'Slow')
      slow_node = "class Shout < Raindown::Node\n  def replace = sleep(3) && 'Slow'\nend\n"
      File.write(File.join(@dir, 'raindeer', '.raindown', 'shout.rb'), slow_node)
      fast = project('raindown', shout: 'Fast')

      expect do
        supervisor.handle([slow, fast])
        expect([eventually(timeout: 2) { File.read(fast).include?('Fast') }, File.read(slow)]).to eq([true, "# Notes\n\nShout:\n"])
        eventually { File.read(slow).include?('Slow') }
      end.to output.to_stdout_from_any_process
    end

    it 'says when a worker stops partway, and starts it again for the next change' do
      raindeer = project('raindeer', shout: 'Hi')
      # The node leaves a mark as it stops its worker, so it's not changed back before the worker's loaded it.
      crashed = File.join(@dir, 'crashed')
      File.write(File.join(@dir, 'raindeer', '.raindown', 'shout.rb'),
                 "class Shout < Raindown::Node\n  def replace = File.write('#{crashed}', '') && exit!(1)\nend\n")

      expect do
        supervisor.handle([raindeer])
        eventually { File.exist?(crashed) }
        node(File.join(@dir, 'raindeer'), 'Fine')
        supervisor.handle([File.join(@dir, 'raindeer', '.raindown', 'shout.rb'), raindeer])
        eventually { File.read(raindeer).include?('Fine') }
      end.to output(/\[raindeer\] raindown: The worker for raindeer stopped/).to_stderr_from_any_process
      expect(File.read(raindeer)).to eq("# Notes\n\nShout:\nFine\n")
    end

    it 'starts a worker for each project as its files change' do
      raindeer = project('raindeer', shout: 'Hi')
      project('raindown', shout: 'Hi')

      expect do
        supervisor.handle([raindeer])
        eventually { File.read(raindeer).include?('Hi') }
      end.to output.to_stdout_from_any_process
      expect(supervisor.workers.started.keys).to eq([File.join(@dir, 'raindeer')])
    end
  end

  context 'without fork' do
    before { allow(Process).to receive(:respond_to?).and_call_original }
    before { allow(Process).to receive(:respond_to?).with(:fork).and_return(false) }

    it 'writes back in this process' do
      raindeer = project('raindeer', shout: 'Shared process')

      expect { supervisor.handle([raindeer]) }.to output("[raindeer] Updated notes.rd\n").to_stdout

      expect(File.read(raindeer)).to eq("# Notes\n\nShout:\nShared process\n")
      expect(supervisor.workers.started.values).to all(be_a(Raindown::Workers::Worker))
    end

    it "says to restart when a project's nodes change, as they can't be unloaded" do
      project('raindeer', shout: 'Hi')

      expect { supervisor.handle([File.join(@dir, 'raindeer', '.raindown', 'shout.rb')]) }
        .to output(/\[raindeer\] Restart raindown to load the node changes/).to_stderr
    end
  end

  it 'leaves files outside projects and in ignored folders alone' do
    project('raindeer', shout: 'Hi')
    outside = File.join(@dir, 'outside.md').tap { File.write(it, "# Outside\n\n<{ toc: }>\n<{ :toc }>\n") }
    dependency = File.join(@dir, 'raindeer', 'node_modules', 'pkg', 'README.md')
    FileUtils.mkdir_p(File.dirname(dependency))
    File.write(dependency, "# Dependency\n\n<{ toc: }>\n<{ :toc }>\n")

    supervisor.handle([outside, dependency, File.join(@dir, 'raindeer', 'notes.txt')])

    expect(supervisor.workers.started).to be_empty
    expect([File.read(outside), File.read(dependency)]).to all(include("<{ toc: }>\n<{ :toc }>"))
  end
end
