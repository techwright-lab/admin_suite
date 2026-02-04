# frozen_string_literal: true

module AdminSuite
  module PanelsHelper
    # Renders a portal dashboard rows grid.
    #
    # @param rows [Array<AdminSuite::UI::RowDefinition>]
    def render_dashboard_rows(rows)
      return "" if rows.blank?

      content_tag(:div, class: "space-y-6") do
        rows.each do |row|
          concat(content_tag(:div, class: "grid grid-cols-1 lg:grid-cols-3 gap-6") do
            Array(row.panels).each do |panel|
              concat(render_panel(panel))
            end
          end)
        end
      end
    end

    # Renders a single panel by selecting a partial.
    #
    # Host apps can override by setting `AdminSuite.config.partials[:panel_<type>]`.
    #
    # @param panel [AdminSuite::UI::PanelDefinition]
    def render_panel(panel)
      type = panel.type.to_sym
      override = AdminSuite.config.partials[:"panel_#{type}"] rescue nil
      partial = override.presence || "admin_suite/panels/#{type}"
      render partial:, locals: { panel: panel }
    end

    # Evaluates a panel option, calling Procs if needed.
    #
    # @param value [Object, Proc]
    # @return [Object]
    def panel_eval(value)
      return value.call if value.is_a?(Proc) && value.arity == 0
      return value.call(self) if value.is_a?(Proc) && value.arity == 1
      value
    end
  end
end
