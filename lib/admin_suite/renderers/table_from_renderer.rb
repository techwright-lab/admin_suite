# frozen_string_literal: true

module AdminSuite
  module Renderers
    # Table panel over an Array of Hashes. Columns default to the first row's keys.
    class TableFromRenderer < Renderer
      def render
        rows = source_value([]) || []
        unless rows.is_a?(Array)
          raise ArgumentError, "table_from expects an Array of Hashes, got #{rows.class}"
        end

        columns = options[:columns].presence || rows.first&.keys || []
        data_table(rows, columns: columns.map(&:to_sym), empty: options[:empty])
      end
    end
  end
end
