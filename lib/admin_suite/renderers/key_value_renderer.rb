# frozen_string_literal: true

module AdminSuite
  module Renderers
    # Label/value list panel. `source:` returns a Hash or an Array of
    # [key, value] pairs.
    #
    # Unlike `data_table`, the `key_value_list` primitive has no `empty:`
    # option (see Task 4 report for why) — emptiness is handled here instead.
    class KeyValueRenderer < Renderer
      def render
        value = source_value({})
        pairs =
          case value
          when Hash then value.to_a
          when Array then value
          when nil then []
          else
            # A Hash is handled above; anything else that coerces via #to_a
            # (AR relations, Sets, ...) is supported the same way `Array(value)`
            # supported it before this guard existed — only reject things
            # that genuinely aren't enumerable.
            unless value.respond_to?(:to_a)
              raise ArgumentError, "key_value expects a Hash or an Array of pairs, got #{value.class}"
            end
            value.to_a
          end
        return empty_state(options[:empty] || "Nothing to display.") if pairs.blank?

        unless pairs.all? { |pair| pair.is_a?(Array) && pair.size == 2 }
          raise ArgumentError, "key_value expects a Hash or an Array of [key, value] pairs, " \
                                "got an Array containing non-pair elements"
        end

        key_value_list(pairs.map { |k, v| [ k.to_s.humanize, v ] })
      end
    end
  end
end
