# frozen_string_literal: true

module AdminSuite
  class PortalsController < ApplicationController
    def show
      ensure_portals_loaded!
      @portal_key = params[:portal].to_s.presence&.to_sym
      @portal = navigation_items[@portal_key]
      @portal_definition = AdminSuite::PortalRegistry.fetch(@portal_key)

      raise ActionController::RoutingError, "Portal not found" if @portal.blank?

      @sections =
        (@portal[:sections] || {}).sort_by { |(_k, s)| s[:label].to_s }.map do |section_key, section|
          items = Array(section[:items]).sort_by { |it| it[:label].to_s }
          [ section_key, section.merge(items: items) ]
        end

      @dashboard_rows = @portal_definition&.dashboard_definition&.rows
    end
  end
end
