# frozen_string_literal: true

module Admin
  module Base
    # Base class for admin portals
    #
    # A portal is a logical grouping of admin resources with its own
    # navigation, dashboard, and access controls.
    #
    # @example
    #   class Admin::Portals::OpsPortal < Admin::Base::Portal
    #     name "Operations"
    #     icon :building
    #     path_prefix "/admin/ops"
    #
    #     section :users_email do
    #       label "Users & Email"
    #       icon :users
    #       resources :users, :email_senders, :connected_accounts
    #     end
    #   end
    class Portal
      class << self
        attr_reader :portal_name, :portal_icon, :portal_path_prefix, :sections_list

        # Sets the portal display name
        #
        # @param value [String] Portal name
        # @return [void]
        def name(value)
          @portal_name = value
        end

        # Sets the portal icon
        #
        # @param value [Symbol] Icon name
        # @return [void]
        def icon(value)
          @portal_icon = value
        end

        # Sets the path prefix for this portal
        #
        # @param value [String] Path prefix
        # @return [void]
        def path_prefix(value)
          @portal_path_prefix = value
        end

        # Defines a section within the portal
        #
        # @param key [Symbol] Section key
        # @yield Block for section configuration
        # @return [void]
        def section(key, &block)
          @sections_list ||= []
          section = SectionConfig.new(key)
          section.instance_eval(&block) if block_given?
          @sections_list << section
        end

        # Returns the portal identifier
        #
        # @return [Symbol]
        def identifier
          portal_name.to_s.parameterize.underscore.to_sym
        end

        # Returns resources for this portal
        #
        # @return [Array<Class>]
        def resources
          Resource.resources_for_portal(identifier)
        end

        # Returns all registered portals
        #
        # @return [Array<Class>]
        def registered_portals
          @registered_portals ||= []
        end

        # Called when a subclass is created
        def inherited(subclass)
          super
          # Use to_s to get class name to avoid conflict with our custom name(value) method
          class_name = subclass.to_s
          registered_portals << subclass unless class_name.include?("Base")
        end

        # Finds a portal by identifier
        #
        # @param identifier [Symbol] Portal identifier
        # @return [Class, nil]
        def find(identifier)
          registered_portals.find { |p| p.identifier == identifier.to_sym }
        end
      end

      # Section configuration within a portal
      class SectionConfig
        attr_reader :key, :section_label, :section_icon, :resource_keys

        def initialize(key)
          @key = key
          @resource_keys = []
        end

        # Sets the section label
        #
        # @param value [String] Section label
        # @return [void]
        def label(value)
          @section_label = value
        end

        # Sets the section icon
        #
        # @param value [Symbol] Icon name
        # @return [void]
        def icon(value)
          @section_icon = value
        end

        # Adds resources to this section
        #
        # @param keys [Array<Symbol>] Resource keys
        # @return [void]
        def resources(*keys)
          @resource_keys.concat(keys)
        end

        # Returns the display label
        #
        # @return [String]
        def display_label
          section_label || key.to_s.humanize
        end
      end
    end
  end
end

