# frozen_string_literal: true

module AdminSuite
  module UI
    PanelDefinition = Struct.new(:type, :title, :options, keyword_init: true)
    RowDefinition = Struct.new(:panels, keyword_init: true)

    class DashboardDefinition
      attr_reader :rows

      def initialize
        @rows = []
      end
    end

    # DSL used inside `portal.dashboard do ... end`.
    class DashboardDSL
      def initialize(definition)
        @definition = definition
      end

      def row(&block)
        row = RowDefinition.new(panels: [])
        RowDSL.new(row).instance_eval(&block) if block_given?
        @definition.rows << row
        row
      end
    end

    # DSL used inside `row do ... end`.
    class RowDSL
      def initialize(row)
        @row = row
      end

      def panel(type, title = nil, span: nil, **options, &block)
        options[:span] = span if span
        options[:block] = block if block_given?
        @row.panels << PanelDefinition.new(type: type.to_sym, title: title, options: options)
      end

      def stat_panel(title, value = nil, span: nil, **options, &block)
        value_proc = value.is_a?(Proc) ? value : (block_given? ? block : nil)
        panel(:stat, title, span: span, **options.merge(value: value_proc || value))
      end

      def health_panel(title, status: nil, metrics: nil, span: nil, **options, &block)
        panel(:health, title, span: span, **options.merge(status: status, metrics: metrics, block: block))
      end

      def chart_panel(title, data: nil, span: nil, **options, &block)
        data_proc = data.is_a?(Proc) ? data : (block_given? ? block : nil)
        panel(:chart, title, span: span, **options.merge(data: data_proc || data))
      end

      def cards_panel(title, resources: nil, span: nil, **options, &block)
        panel(:cards, title, span: span, **options.merge(resources: resources, block: block))
      end

      def recent_panel(title, scope: nil, link: nil, span: nil, **options, &block)
        panel(:recent, title, span: span, **options.merge(scope: scope, link: link, block: block))
      end

      def table_panel(title, rows: nil, columns: nil, span: nil, **options, &block)
        panel(:table, title, span: span, **options.merge(rows: rows, columns: columns, block: block))
      end
    end
  end
end
