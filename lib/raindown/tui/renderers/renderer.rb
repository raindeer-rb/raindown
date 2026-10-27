# frozen_string_literal: true

require_relative '../events'
require_relative '../rows'
require_relative '../text'

module Raindown
  module TUI
    # Draws what's in a pane, :nav or :main, as lines of the pane's width and height, which the Layout puts in it.
    Renderer = Struct.new(:navigator, :pane, :width, :height) do
      include Rows
      include Text
    end
  end
end
