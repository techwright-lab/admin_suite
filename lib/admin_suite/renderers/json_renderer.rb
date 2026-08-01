# frozen_string_literal: true

module AdminSuite
  module Renderers
    # Pretty-printed JSON panel. `source:` defaults to the record's attributes.
    class JsonRenderer < Renderer
      def render
        value = source_value(record.respond_to?(:attributes) ? record.attributes : record)
        return empty_state(options[:empty] || "Nothing to display.") if value.blank?

        json_block(value)
      end
    end
  end
end
