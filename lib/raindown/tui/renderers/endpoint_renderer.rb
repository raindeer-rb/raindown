# frozen_string_literal: true

require_relative 'renderer'
require_relative 'outline_renderer'

module Raindown
  module TUI
    # An endpoint opened from the files, right of them: its URL in a bar with rounded corners, and a button to run it,
    # then its response:
    #    ╭──────────────────────────────────────────╮
    #    │ GET https://httpbin.org/uuid     [ Run ] │
    #    ╰──────────────────────────────────────────╯
    #
    #    Response · json · fetched 2026-10-26
    #    {
    #      "uuid": "48024974-f1b1-431a-a0cf-5cac0099a1a5"
    #    }
    class EndpointRenderer < Renderer
      RUN = '[ Run ]'
      RUN_WIDTH = RUN.length
      BUTTONS = OutlineRenderer::BUTTONS.reject { it.last == :write_back }.freeze

      def buttons = BUTTONS
      def page = navigator.view.endpoint.text

      def lines
        view = navigator.view
        top = [*url_bar(view.endpoint), [segment('', :blank, width:)], about(view)]

        (top + response(view, height - top.length)).first(height)
      end

      private

      # A click on the response moves the focus to it, to scroll it.
      def focus = Click.new(pane:, index: 0, action: :focus)

      def response(view, lines)
        texts = view.visible([lines, 0].max)
        Array.new([lines, 0].max) { [segment(texts[it] ? " #{texts[it]}" : '', :response, width:, event: focus)] }
      end

      # The bar is a column in from each side of the pane, with the URL and the button inside its border.
      def url_bar(endpoint)
        inner = [width - 6, 0].max
        [edge('╭', '╮', inner), padded([margin, segment('│ ', :border, width: 2), *request(endpoint, inner)]),
         edge('╰', '╯', inner)]
      end

      # The method in its colour, then the URL, cut to what the method and button leave, then the button,
      # and the border's side.
      def request(endpoint, inner)
        method_width = display_width(endpoint.method)
        url_width = [inner - method_width - RUN_WIDTH - 1, 0].max

        [segment(endpoint.method, endpoint.style, width: method_width), segment(" #{endpoint.url} ", :url, width: url_width + 1),
         run_button, segment(' │', :border, width: 2)]
      end

      def run_button = segment(RUN, :run, width: RUN_WIDTH, event: Click.new(pane:, index: 0, action: :execute))

      def edge(left, right, inner)
        padded([margin, segment("#{left}#{'─' * (inner + 2)}#{right}", :border, width: inner + 4)])
      end

      def margin = segment('', :blank, width: 1)

      def about(view)
        text = if view.error then view.error
               elsif view.response.empty? then 'No response yet. X runs the request.'
               else ['Response', view.language, ("fetched #{view.fetched}" if view.fetched)].reject { it.to_s.empty? }.join(' · ')
               end
        [segment(" #{text}", view.error ? :error : :heading, width:)]
      end
    end
  end
end
