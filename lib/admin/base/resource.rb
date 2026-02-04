# frozen_string_literal: true

module Admin
  module Base
    # Base class for admin resource definitions
    #
    # Provides a declarative DSL for defining admin resources with:
    # - Index configuration (columns, filters, search, sort, stats)
    # - Form configuration (fields with various types)
    # - Actions (single and bulk)
    # - Show page sections
    # - Export capabilities
    #
    # @example
    #   class Admin::Resources::CompanyResource < Admin::Base::Resource
    #     model Company
    #     portal :ops
    #     section :content
    #
    #     index do
    #       searchable :name, :website
    #       sortable :name, :created_at, default: :name
    #
    #       columns do
    #         column :name
    #         column :job_listings, -> (c) { c.job_listings.count }
    #       end
    #
    #       filters do
    #         filter :search, type: :text
    #         filter :status, type: :select, options: %w[active inactive]
    #       end
    #     end
    #
    #     form do
    #       field :name, required: true
    #       field :website, type: :url
    #       field :is_active, type: :toggle
    #     end
    #   end
    class Resource
      class << self
        # Model configuration
        attr_reader :model_class, :portal_name, :section_name, :nav_label, :nav_icon, :nav_order

        # Index configuration
        attr_reader :index_config

        # Form configuration
        attr_reader :form_config

        # Show configuration
        attr_reader :show_config

        # Actions configuration
        attr_reader :actions_config

        # Export configuration
        attr_reader :export_formats

        # Sets the model class for this resource
        #
        # @param klass [Class] The ActiveRecord model class
        # @return [void]
        def model(klass)
          @model_class = klass
        end

        # Sets the portal this resource belongs to
        #
        # @param name [Symbol] Portal name (:ops or :ai)
        # @return [void]
        def portal(name)
          @portal_name = name
        end

        # Sets the section within the portal
        #
        # @param name [Symbol] Section name
        # @return [void]
        def section(name)
          @section_name = name
        end

        # Navigation metadata for this resource.
        #
        # @param label [String, nil] override label used in nav
        # @param icon [String, Symbol, nil] lucide icon name (or raw svg string)
        # @param order [Integer, nil] sort order within section
        # @return [void]
        def nav(label: nil, icon: nil, order: nil)
          @nav_label = label if label.present?
          @nav_icon = icon if icon.present?
          @nav_order = order unless order.nil?
        end

        # Convenience setter/getter for nav icon.
        #
        # @param name [String, Symbol, nil]
        # @return [String, Symbol, nil]
        def icon(name = nil)
          @nav_icon = name if name.present?
          @nav_icon
        end

        # Convenience setter/getter for nav label.
        #
        # @param name [String, nil]
        # @return [String, nil]
        def label(name = nil)
          @nav_label = name if name.present?
          @nav_label
        end

        # Convenience setter/getter for nav order.
        #
        # @param value [Integer, nil]
        # @return [Integer, nil]
        def order(value = nil)
          @nav_order = value unless value.nil?
          @nav_order
        end

        # Configures the index view
        #
        # @yield Block for index configuration
        # @return [void]
        def index(&block)
          @index_config = IndexConfig.new
          @index_config.instance_eval(&block) if block_given?
        end

        # Configures the form (new/edit)
        #
        # @yield Block for form configuration
        # @return [void]
        def form(&block)
          @form_config = FormConfig.new
          @form_config.instance_eval(&block) if block_given?
        end

        # Configures the show view
        #
        # @yield Block for show configuration
        # @return [void]
        def show(&block)
          @show_config = ShowConfig.new
          @show_config.instance_eval(&block) if block_given?
        end

        # Configures actions
        #
        # @yield Block for actions configuration
        # @return [void]
        def actions(&block)
          @actions_config = ActionsConfig.new
          @actions_config.instance_eval(&block) if block_given?
        end

        # Configures export formats
        #
        # @param formats [Array<Symbol>] Export formats (:json, :csv)
        # @return [void]
        def exportable(*formats)
          @export_formats = formats
        end

        # Returns the resource name derived from class name
        #
        # @return [String]
        def resource_name
          name.demodulize.sub(/Resource$/, "").underscore
        end

        # Returns the plural resource name
        #
        # @return [String]
        def resource_name_plural
          resource_name.pluralize
        end

        # Returns the human-readable name
        #
        # @return [String]
        def human_name
          model_class&.model_name&.human || resource_name.humanize
        end

        # Returns the human-readable plural name
        #
        # @return [String]
        def human_name_plural
          model_class&.model_name&.human(count: 2) || resource_name.pluralize.humanize
        end

        # Returns all registered resources
        #
        # @return [Array<Class>]
        def registered_resources
          @registered_resources ||= []
        end

        # Clears the registry (useful for development reloads).
        #
        # @return [void]
        def reset_registry!
          @registered_resources = []
        end

        # Called when a subclass is created
        def inherited(subclass)
          super
          return if subclass.name&.include?("Base")

          existing_idx = registered_resources.index { |r| r.name == subclass.name }
          if existing_idx
            registered_resources[existing_idx] = subclass
          else
            registered_resources << subclass
          end
        end

        # Returns resources for a specific portal
        #
        # @param portal [Symbol] Portal name
        # @return [Array<Class>]
        def resources_for_portal(portal)
          registered_resources.select { |r| r.portal_name == portal }
        end

        # Returns resources for a specific section
        #
        # @param portal [Symbol] Portal name
        # @param section [Symbol] Section name
        # @return [Array<Class>]
        def resources_for_section(portal, section)
          registered_resources.select { |r| r.portal_name == portal && r.section_name == section }
        end
      end

      # Index view configuration
      class IndexConfig
        attr_reader :searchable_fields, :sortable_fields, :default_sort, :default_sort_direction,
                    :columns_list, :filters_list, :stats_list, :per_page

        def initialize
          @searchable_fields = []
          @sortable_fields = []
          @default_sort = nil
          @default_sort_direction = :desc
          @columns_list = []
          @filters_list = []
          @stats_list = []
          @per_page = 25
        end

        def searchable(*fields)
          @searchable_fields = fields
        end

        def sortable(*fields, default: nil, direction: :desc)
          @sortable_fields = fields if fields.any?
          @default_sort = default || fields.first
          @default_sort_direction = direction
        end

        def paginate(count)
          @per_page = count
        end

        def columns(&block)
          builder = ColumnsBuilder.new
          builder.instance_eval(&block) if block_given?
          @columns_list = builder.columns
        end

        def filters(&block)
          builder = FiltersBuilder.new
          builder.instance_eval(&block) if block_given?
          @filters_list = builder.filters
        end

        def stats(&block)
          builder = StatsBuilder.new
          builder.instance_eval(&block) if block_given?
          @stats_list = builder.stats
        end
      end

      class ColumnsBuilder
        attr_reader :columns

        def initialize
          @columns = []
        end

        def column(name, content = nil, **options)
          @columns << ColumnDefinition.new(
            name: name,
            content: content,
            render: options[:render],
            header: options[:header] || name.to_s.humanize,
            css_class: options[:class],
            type: options[:type],
            toggle_field: options[:toggle_field],
            label_color: options[:label_color],
            label_size: options[:label_size],
            sortable: options[:sortable] || false
          )
        end
      end

      ColumnDefinition = Struct.new(:name, :content, :render, :header, :css_class, :type, :toggle_field, :label_color, :label_size, :sortable, keyword_init: true)

      class FiltersBuilder
        attr_reader :filters

        def initialize
          @filters = []
        end

        def filter(name, **options)
          select_options = options.key?(:options) ? options[:options] : options[:collection]
          @filters << FilterDefinition.new(
            name: name,
            type: options[:type] || :text,
            label: options[:label] || name.to_s.humanize,
            placeholder: options[:placeholder],
            options: select_options,
            field: options[:field] || name,
            apply: options[:apply]
          )
        end
      end

      FilterDefinition = Struct.new(:name, :type, :label, :placeholder, :options, :field, :apply, keyword_init: true)

      class StatsBuilder
        attr_reader :stats

        def initialize
          @stats = []
        end

        def stat(name, calculator, **options)
          @stats << StatDefinition.new(
            name: name,
            calculator: calculator,
            color: options[:color]
          )
        end
      end

      StatDefinition = Struct.new(:name, :calculator, :color, keyword_init: true)

      class FormConfig
        attr_reader :fields_list

        def initialize
          @fields_list = []
        end

        def field(name, **options)
          @fields_list << FieldDefinition.new(
            name: name,
            type: options[:type] || :text,
            required: options[:required] || false,
            label: options[:label] || name.to_s.humanize,
            help: options[:help],
            placeholder: options[:placeholder],
            collection: options[:collection],
            create_url: options[:create_url],
            accept: options[:accept],
            rows: options[:rows],
            readonly: options[:readonly] || false,
            if_condition: options[:if],
            unless_condition: options[:unless],
            multiple: options[:multiple] || false,
            creatable: options[:creatable] || false,
            preview: options[:preview] != false,
            variants: options[:variants],
            label_color: options[:label_color],
            label_size: options[:label_size]
          )
        end

        def section(title, **options, &block)
          @fields_list << SectionDefinition.new(
            title: title,
            description: options[:description],
            collapsible: options[:collapsible] || false,
            collapsed: options[:collapsed] || false
          )
          instance_eval(&block) if block_given?
          @fields_list << SectionEnd.new
        end

        def row(**options, &block)
          @fields_list << RowDefinition.new(cols: options[:cols] || 2)
          instance_eval(&block) if block_given?
          @fields_list << RowEnd.new
        end
      end

      FieldDefinition = Struct.new(
        :name, :type, :required, :label, :help, :placeholder,
        :collection, :create_url, :accept, :rows, :readonly,
        :if_condition, :unless_condition, :multiple, :creatable,
        :preview, :variants, :label_color, :label_size,
        keyword_init: true
      )

      SectionDefinition = Struct.new(:title, :description, :collapsible, :collapsed, keyword_init: true)
      SectionEnd = Class.new

      RowDefinition = Struct.new(:cols, keyword_init: true)
      RowEnd = Class.new

      class ShowConfig
        attr_reader :sidebar_sections, :main_sections

        def initialize
          @sidebar_sections = []
          @main_sections = []
        end

        def section(name, **options)
          @main_sections << build_section(name, options)
        end

        def sidebar(&block)
          @current_target = :sidebar
          instance_eval(&block) if block_given?
          @current_target = nil
        end

        def main(&block)
          @current_target = :main
          instance_eval(&block) if block_given?
          @current_target = nil
        end

        def panel(name, **options)
          section_def = build_section(name, options)

          case @current_target
          when :sidebar
            @sidebar_sections << section_def
          else
            @main_sections << section_def
          end
        end

        def sections_list
          @main_sections
        end

        private

        def build_section(name, options)
          ShowSectionDefinition.new(
            name: name,
            fields: options[:fields] || [],
            association: options[:association],
            limit: options[:limit],
            render: options[:render],
            title: options[:title] || name.to_s.humanize,
            display: options[:display] || :list,
            columns: options[:columns] || [],
            link_to: options[:link_to],
            resource: options[:resource],
            paginate: options[:paginate] || options[:pagination] || false,
            per_page: options[:per_page],
            collapsible: options[:collapsible] || false,
            collapsed: options[:collapsed] || false
          )
        end
      end

      ShowSectionDefinition = Struct.new(
        :name, :fields, :association, :limit, :render, :title,
        :display, :columns, :link_to, :resource, :paginate, :per_page, :collapsible, :collapsed,
        keyword_init: true
      )

      class ActionsConfig
        attr_reader :member_actions, :collection_actions, :bulk_actions

        def initialize
          @member_actions = []
          @collection_actions = []
          @bulk_actions = []
        end

        def action(name, **options)
          @member_actions << ActionDefinition.new(
            name: name,
            method: options[:method] || :post,
            confirm: options[:confirm],
            type: options[:type] || :button,
            label: options[:label] || name.to_s.humanize,
            icon: options[:icon],
            color: options[:color],
            if_condition: options[:if],
            unless_condition: options[:unless]
          )
        end

        def collection_action(name, **options)
          @collection_actions << ActionDefinition.new(
            name: name,
            method: options[:method] || :post,
            confirm: options[:confirm],
            type: options[:type] || :button,
            label: options[:label] || name.to_s.humanize,
            icon: options[:icon],
            color: options[:color]
          )
        end

        def bulk_action(name, **options)
          @bulk_actions << ActionDefinition.new(
            name: name,
            method: options[:method] || :post,
            confirm: options[:confirm],
            type: options[:type] || :button,
            label: options[:label] || name.to_s.humanize,
            icon: options[:icon],
            color: options[:color]
          )
        end
      end

      ActionDefinition = Struct.new(
        :name, :method, :confirm, :type, :label, :icon, :color,
        :if_condition, :unless_condition,
        keyword_init: true
      )
    end
  end
end
