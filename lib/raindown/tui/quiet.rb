# frozen_string_literal: true

require 'stringio'

module Raindown
  module TUI
    # Keeps text off the screen while it's up, since it would be written over it, and scroll it from the bottom line.
    module Quiet
      module_function

      # What's written to stderr while the block runs, like a warning, is written once it's done.
      def holding_stderr
        stderr = $stderr
        $stderr = StringIO.new
        yield
      ensure
        held = $stderr.string
        $stderr = stderr
        $stderr.write(held) unless held.empty?
      end

      # Ruby's warnings are off while the block runs.
      def quietly
        verbose = $VERBOSE
        $VERBOSE = nil
        yield
      ensure
        $VERBOSE = verbose
      end
    end
  end
end
