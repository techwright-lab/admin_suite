# frozen_string_literal: true

module AdminSuite
  module Renderers
    # Syntax-highlighted code panel.
    class CodeRenderer < Renderer
      def render
        text = source_value(record.respond_to?(:code) ? record.code : record.to_s)
        return empty_state(options[:empty] || "Nothing to display.") if text.blank?

        code_block(text.to_s, language: options[:language])
      end
    end
  end
end
