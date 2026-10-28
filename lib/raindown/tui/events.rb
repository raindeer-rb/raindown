# frozen_string_literal: true

module Raindown
  module TUI
    # A click on the screen: the cursor moves to the pane's row, or the dashboard's card or the menu's item,
    # then the action's done there, like :enter, or a button's, like :toggle or :execute.
    # Keys are their events' names, like :down or :enter.
    Click = Data.define(:pane, :index, :action)

    # The mouse moving over what a click there would send, if anything, to show it, like a method's cells in bold.
    Hover = Data.define(:target)

    # A character typed while typing, like in the search, which other keys' events would take, like "j" for :down.
    Type = Data.define(:text)

    # What the Screen does after an event, other than drawing again, or stopping for :quit.
    # Leaves the screen for a command, like the editor, then tells the Navigator it ran.
    Run = Data.define(:command)

    # Shows the message while the task runs, like an endpoint's request.
    Wait = Data.define(:message, :task)

    # Steps a row or a view asks of the Navigator, which each takes on it, returning what the Screen does next: to open
    # a view right of the files, or a file in the outline at a directive, to edit a file at a line, to run an endpoint,
    # to draw the page a feeling was noted down in, or to ask Claude Code to fix a method.
    OpenView = Data.define(:view) do
      def take(navigator) = navigator.open_view(view)
    end

    Open = Data.define(:path, :line) do
      def take(navigator) = navigator.open_at(path, line)
    end

    Edit = Data.define(:path, :line) do
      def take(navigator) = navigator.edit_at(path, line)
    end

    Execute = Data.define(:path, :line, :name) do
      def take(navigator) = navigator.run(path, line, name)
    end

    Felt = Data.define(:feeling) do
      def take(navigator) = navigator.felt(feeling)
    end

    Fix = Data.define(:feeling) do
      def take(navigator) = navigator.fix_with_agent(feeling)
    end
  end
end
