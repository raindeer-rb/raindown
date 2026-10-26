# frozen_string_literal: true

module Raindown
  module TUI
    # A click on the screen: the cursor moves to the pane's row, or the dashboard's card or the menu's item,
    # then the action's done there, like :enter, or a button's, like :toggle or :execute.
    # Keys are their events' names, like :down or :enter.
    Click = Data.define(:pane, :index, :action)

    # What the Screen does after an event, other than drawing again, or stopping for :quit.
    # Leaves the screen for a command, like the editor, then tells the Navigator it ran.
    Run = Data.define(:command)
    # Shows the message while the task runs, like an endpoint's request.
    Wait = Data.define(:message, :task)

    # What the Dashboard asks of the Navigator for a chart: to open its file in the outline at its directive, or edit it.
    Open = Data.define(:path, :line)
    Edit = Data.define(:path, :line)
  end
end
