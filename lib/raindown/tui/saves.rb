# frozen_string_literal: true

require 'listen'
require_relative '../supervisor'

module Raindown
  module TUI
    # The files saved, added or removed in the terminal UI's folder, like when it's watched, but kept until the Navigator
    # takes them on its next tick, as Listen tells of them in a thread of its own.
    class Saves
      def initialize(root)
        @queue = Thread::Queue.new
        @listener = Listen.to(root, ignore: Supervisor::IGNORE) do |modified, added, removed|
          (modified + added + removed).each { @queue << it }
        end
        @listener.start
      end

      # The paths saved since they were last taken, once each.
      def take = Array.new(@queue.size) { @queue.pop }.uniq

      def stop = @listener.stop
    end
  end
end
