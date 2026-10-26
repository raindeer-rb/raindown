# frozen_string_literal: true

module Raindown
  module TUI
    # An endpoint in a project's files, listed in the files pane by its request, like "GET httpbin.org/uuid",
    # with its method in its style, like GET in :method_get.
    Endpoint = Data.define(:project, :path, :line, :method, :url) do
      def text = "#{method} #{address}"

      # The URL without its scheme.
      def address = url.sub(%r{\Ahttps?://}i, '')

      def style = :"method_#{method.downcase}"
    end
  end
end
