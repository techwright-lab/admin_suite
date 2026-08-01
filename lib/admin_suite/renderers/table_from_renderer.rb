# frozen_string_literal: true

module AdminSuite
  module Renderers
    # Table panel over an Array of Hashes. Columns default to the first row's keys.
    class TableFromRenderer < Renderer
      def render
        rows = source_value([]) || []
        # A Hash source is the contract violation worth naming; other
        # Enumerables (AR relations, Sets, ...) coerce cleanly via #to_a and
        # were supported before this guard existed — don't narrow that away.
        rows = rows.to_a if !rows.is_a?(Array) && !rows.is_a?(Hash) && rows.respond_to?(:to_a)
        unless rows.is_a?(Array)
          raise ArgumentError, "table_from expects an Array of Hashes, got #{rows.class}"
        end

        columns = options[:columns].presence || rows.first&.keys || []
        data_table(rows, columns: columns.map(&:to_sym), empty: options[:empty])
      end
    end
  end
end
