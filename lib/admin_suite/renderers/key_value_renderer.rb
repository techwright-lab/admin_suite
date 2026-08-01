# frozen_string_literal: true

module AdminSuite
  module Renderers
    # Label/value list panel. `source:` returns a Hash or an Array of pairs.
    #
    # Unlike `data_table`, the `key_value_list` primitive has no `empty:`
    # option (see Task 4 report for why) — emptiness is handled here instead.
    class KeyValueRenderer < Renderer
      def render
        value = source_value({})
        pairs = value.is_a?(Hash) ? value.to_a : Array(value)
        return empty_state(options[:empty] || "Nothing to display.") if pairs.blank?

        key_value_list(pairs.map { |k, v| [ k.to_s.humanize, v ] })
      end
    end
  end
end
