# frozen_string_literal: true

module Raindown
  module TUI
    # The list of projects that drops down from the header's path, with "p" or a click, when there's more than one.
    # Choosing one narrows the files and the dashboard to its own, and "All projects" shows every project's again.
    # It stays open until a project's chosen, with Enter or a click, which is Enter on the project clicked,
    # while up and down move its cursor.
    # Esc or "p" close it without choosing, and other keys and clicks do nothing while it's open.
    module ProjectMenu
      # The menu's cursor, while it's open.
      attr_reader :menu

      # The project the files and the dashboard are narrowed to, or nil for every project.
      attr_reader :project

      def projects = @workers.roots

      # The menu's items: nil for all the projects, then each project's root.
      def menu_items = [nil, *projects]

      def projects? = projects.length > 1

      private

      def toggle_menu
        return info("There's one project here") unless projects?

        @menu = @menu ? nil : menu_items.index(project) || 0
        nil
      end

      def menu_event(event)
        name, pane, index = event
        case name
        when :up, :down then move_menu(name == :up ? -1 : 1)
        when :enter then choose(menu_items[@menu])
        when :press then press_menu(index, event.last) if pane == :menu
        when :escape, :projects then close_menu
        end
      end

      def press_menu(index, event)
        @menu = index
        menu_event(event)
      end

      def move_menu(by)
        @menu = (@menu + by).clamp(0, menu_items.length - 1)
        nil
      end

      def close_menu
        @menu = nil
        nil
      end

      # Shows the project's dashboard, or every project's.
      def choose(project)
        @menu = nil
        @project = project
        @files.scope = project
        dashboard.project = project
        open_dashboard
      end
    end
  end
end
