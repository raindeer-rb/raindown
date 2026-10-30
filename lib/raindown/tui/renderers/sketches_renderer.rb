# frozen_string_literal: true

require_relative 'renderer'

module Raindown
  module TUI
    # The sketches from Claude Code's replies, right of the files, below the title of the kind they're filtered to, in the
    # border, which drops down the kinds with how many of each there are: which one of how many, when it was saved and
    # its kind, then the sketch, cut to fit the pane:
    #    ─────────────────── Mockups ▾ ───────────────────
    #     3 of 12 · 2026-10-30 03:14 UTC · mockup  ┌───────────────┐
    #                                              │ All        23 │
    #     ╭─ Weather Report ─────╮                 │ Mockups ✓  12 │
    #     │  .--.   Light rain   │                 └───────────────┘
    class SketchesRenderer < Renderer
      BUTTONS = [['Tab', 'Pane', :tab], ['Enter', 'Kind', :kinds], ['←→', 'Sketch', nil], ['e', 'Edit', :edit],
                 ['/', 'Search', :search], ['q', 'Quit', :quit]].freeze

      def buttons = BUTTONS
      def page = 'Sketches'

      # The kind the sketches are filtered to, in the middle of the line above the panes, which drops down the kinds.
      def spacer
        title = " #{Sketches::KINDS.fetch(view.kind, 'All sketches')} ▾ "
        title_width = display_width(title)
        left = [(width - title_width) / 2, 0].max
        padded([segment('', :blank, width: left), segment(title, :divider, width: title_width, event: kinds_click),
                segment('', :blank, width: [width - left - title_width, 0].max)])
      end

      def lines
        lines = sketch_lines
        return lines unless view.menu

        box = menu
        column = [(width - display_width(box.first.first.text)) / 2, 0].max
        box.first(height).each_with_index { |segments, row| lines[row] = overlay_segments(lines[row], segments, column:) }
        lines
      end

      private

      def view = navigator.view

      # The click on the title, or on Enter's button, which keeps the sketch shown.
      def kinds_click = Click.new(pane:, index: view.cursor, action: :kinds)

      def sketch_lines
        sketch = view.selected
        return blank(" No #{Sketches::KINDS.fetch(view.kind, 'sketches').downcase} yet. #{saving}") unless sketch

        [[segment(about(sketch), :heading)], [segment('', :blank)], *sketch.lines.map { [segment(" #{it}", :text)] }, *blank('')]
          .first(height)
      end

      # Which one it is of how many, when it was saved, and its kind.
      def about(sketch)
        " #{view.cursor + 1} of #{view.sketches.length} · #{sketch.time.sub('T', ' ').sub(/:\d\dZ\z/, ' UTC')} · #{sketch.kind}"
      end

      def saving = "Claude Code's are saved to #{Sketches::FILE} by `raindown sketches`."

      # The kinds in a box below the title, each with how many sketches it has, and a tick by the one shown.
      def menu
        names = view.kinds.map { |name, count| [Sketches::KINDS.fetch(name, 'All'), count] }
        inner = names.map { |name, count| display_width("#{name} ✓ #{count}") }.max + 2
        items = names.each_with_index.map { |item, index| menu_line(*item, index, inner) }
        [edge('┌', '┐', inner), *items, edge('└', '┘', inner)]
      end

      def edge(left, right, inner) = [segment("#{left}#{'─' * (inner + 2)}#{right}", :border, width: inner + 4)]

      # An item, which chooses its kind when it's clicked, by its index, as the view's next step.
      def menu_line(name, count, index, inner)
        text = "#{name} #{chosen(index)}".ljust(inner - count.to_s.length) + count.to_s
        click = Click.new(pane:, index: view.cursor, action: index)
        [segment('│ ', :border, width: 2), segment(text, item_style(index), width: inner, event: click), segment(' │', :border, width: 2)]
      end

      # A tick by the kind shown.
      def chosen(index)
        return '✓' if view.kinds[index].first == view.kind

        ' '
      end

      def item_style(index)
        return :selected if view.menu == index

        :menu
      end

      def blank(message)
        [[segment(message, :info)], *Array.new([height - 1, 0].max) { [segment('', :blank)] }]
      end
    end
  end
end
