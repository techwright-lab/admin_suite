# frozen_string_literal: true

module Internal
  module Developer
    # Base controller for the new admin framework at /internal/developer
    #
    # Provides common functionality for all developer portal controllers:
    # - Developer authentication via TechWright SSO
    # - Layout configuration
    # - Resource discovery and resolution
    class BaseController < ApplicationController
      include ActionView::RecordIdentifier

      # Skip regular user authentication - developers use TechWright SSO
      allow_unauthenticated_access

      before_action :require_admin!
      layout "developer"

      helper Internal::Developer::BaseHelper
      helper_method :current_portal, :navigation_items, :resource_config, :current_developer

      private

      # Requires developer authentication via TechWright SSO
      #
      # @return [void]
      def require_admin!
        unless developer_authenticated?
          redirect_to internal_developer_login_path
        end
      end

      # Checks if a developer is currently authenticated
      #
      # @return [Boolean]
      def developer_authenticated?
        current_developer.present?
      end

      # Returns the currently authenticated developer
      #
      # @return [Developer, nil]
      def current_developer
        @current_developer ||= ::Developer.enabled.find_by(id: session[:developer_id])
      end

      # Returns the current portal (ops, ai, or assistant)
      #
      # @return [Symbol, nil]
      def current_portal
        @current_portal ||= determine_portal
      end

      # Determines which portal we're in based on the resource
      #
      # @return [Symbol, nil]
      def determine_portal
        return nil unless resource_config

        resource_config.portal_name
      end

      # Returns the resource configuration class for the current controller
      #
      # @return [Class, nil]
      def resource_config
        @resource_config ||= find_resource_config
      end

      # Finds the resource configuration based on controller name
      #
      # @return [Class, nil]
      def find_resource_config
        resource_name = controller_name.singularize.camelize
        "Admin::Resources::#{resource_name}Resource".constantize
      rescue NameError
        nil
      end

      # Returns navigation items grouped by portal and section
      #
      # @return [Hash]
      def navigation_items
        @navigation_items ||= begin
          # Ensure all resources are loaded in development
          load_resources! if Rails.env.development?
          build_navigation
        end
      end

      # Loads all resource files (needed in development mode)
      #
      # @return [void]
      def load_resources!
        # Skip if already loaded
        return if Admin::Base::Resource.registered_resources.any?

        # Load all resource definitions (require only loads once)
        Dir[Rails.root.join("app/admin/resources/*.rb").to_s].each do |file|
          require file
        end
      rescue NameError
        # Admin::Base::Resource not defined yet, load it first
        require Rails.root.join("app/admin/base/resource.rb").to_s
        retry
      end

      # Builds the navigation structure from registered resources
      #
      # @return [Hash]
      def build_navigation
        navigation = {
          ops: { label: "Ops Portal", icon: "settings", sections: {} },
          email: { label: "Email Portal", icon: "inbox", sections: {} },
          ai: { label: "AI Portal", icon: "cpu", sections: {} },
          assistant: { label: "Assistant Portal", icon: "message-circle", sections: {} }
        }

        Admin::Base::Resource.registered_resources.each do |resource|
          next unless resource.portal_name && resource.section_name

          portal = resource.portal_name
          section = resource.section_name

          navigation[portal][:sections][section] ||= { label: section.to_s.humanize, items: [] }
          navigation[portal][:sections][section][:items] << {
            label: resource.human_name_plural,
            path: url_for(controller: "/internal/developer/#{resource.resource_name_plural}", action: :index),
            resource: resource
          }
        end

        navigation
      end
    end
  end
end
