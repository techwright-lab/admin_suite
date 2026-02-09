# frozen_string_literal: true

module AdminSuite
  class DashboardController < ApplicationController
    def index
      ensure_root_dashboard_loaded!

      items = navigation_items
      @portal_cards = build_portal_cards(items)

      @page_title = eval_setting(AdminSuite.config.root_dashboard_title, default: "Admin Suite")
      @page_description =
        eval_setting(
          AdminSuite.config.root_dashboard_description,
          default: "Admin framework for managing application resources across one or more portals."
        )

      @dashboard_rows = resolve_root_dashboard_rows(items)
    end

    private

    def eval_setting(value, default:)
      evaluated = value.respond_to?(:call) ? value.call(self) : value
      evaluated.to_s.presence || default
    rescue StandardError
      default
    end

    def build_portal_cards(items)
      items.sort_by { |(_k, v)| (v[:order] || 100).to_i }.map do |portal_key, portal|
        color = portal[:color].presence || default_portal_color(portal_key)
        {
          key: portal_key,
          label: portal[:label] || portal_key.to_s.humanize,
          description: portal[:description],
          color: color,
          icon: portal[:icon],
          path: portal_path(portal: portal_key),
          count: (portal[:sections] || {}).values.sum { |s| Array(s[:items]).size }
        }
      end
    end

    def resolve_root_dashboard_rows(items)
      definition = AdminSuite.root_dashboard_definition
      configured_rows = definition&.rows
      return configured_rows unless configured_rows.nil?

      build_default_root_dashboard_rows(items)
    end

    def build_default_root_dashboard_rows(items)
      portal_cards = @portal_cards
      total_portals = items.keys.count
      total_resources = safe_resource_count

      definition = AdminSuite::UI::DashboardDefinition.new
      dsl = AdminSuite::UI::DashboardDSL.new(definition)

      dsl.row do
        cards_panel "Portals", span: 12, variant: :portals, resources: portal_cards
      end

      dsl.row do
        stat_panel "Portals", total_portals, span: 6, variant: :mini, color: :slate
        stat_panel "Resources", total_resources, span: 6, variant: :mini, color: :slate
      end

      definition.rows
    end

    def default_portal_color(portal_key)
      case portal_key.to_sym
      when :ops then "amber"
      when :email then "emerald"
      when :ai then "cyan"
      when :assistant then "violet"
      else "slate"
      end
    end

    def safe_resource_count
      return 0 unless defined?(Admin::Base::Resource)

      Admin::Base::Resource.registered_resources.count
    rescue StandardError
      0
    end
  end
end
