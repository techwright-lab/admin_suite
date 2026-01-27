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
        attr_reader :model_class, :portal_name, :section_name

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

        # Called when a subclass is created
        def inherited(subclass)
          super
          registered_resources << subclass unless subclass.name&.include?("Base")
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

        # Defines searchable fields
        #
        # @param fields [Array<Symbol>] Field names to search
        # @return [void]
        def searchable(*fields)
          @searchable_fields = fields
        end

        # Configures default sort for the index view
        #
        # @param field [Symbol] Default sort field (optional, can also use sortable: true on columns)
        # @param direction [Symbol] Sort direction (:asc or :desc), defaults to :desc
        # @return [void]
        def sortable(*fields, default: nil, direction: :desc)
          # For backwards compatibility, still accept field list
          @sortable_fields = fields if fields.any?
          @default_sort = default || fields.first
          @default_sort_direction = direction
        end

        # Sets items per page
        #
        # @param count [Integer] Number of items per page
        # @return [void]
        def paginate(count)
          @per_page = count
        end

        # Configures columns
        #
        # @yield Block for column configuration
        # @return [void]
        def columns(&block)
          builder = ColumnsBuilder.new
          builder.instance_eval(&block) if block_given?
          @columns_list = builder.columns
        end

        # Configures filters
        #
        # @yield Block for filter configuration
        # @return [void]
        def filters(&block)
          builder = FiltersBuilder.new
          builder.instance_eval(&block) if block_given?
          @filters_list = builder.filters
        end

        # Configures stats
        #
        # @yield Block for stats configuration
        # @return [void]
        def stats(&block)
          builder = StatsBuilder.new
          builder.instance_eval(&block) if block_given?
          @stats_list = builder.stats
        end
      end

      # Column builder for index view
      class ColumnsBuilder
        attr_reader :columns

        def initialize
          @columns = []
        end

        # Adds a column
        #
        # @param name [Symbol] Column name
        # @param content [Proc, nil] Optional proc for custom content
        # @param options [Hash] Column options
        # @option options [Symbol] :render Custom cell renderer
        # @option options [String] :header Custom header text
        # @option options [String] :class CSS classes
        # @option options [Boolean] :sortable Whether column is sortable
        # @return [void]
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

      # Column definition
      ColumnDefinition = Struct.new(:name, :content, :render, :header, :css_class, :type, :toggle_field, :label_color, :label_size, :sortable, keyword_init: true)

      # Filter builder for index view
      class FiltersBuilder
        attr_reader :filters

        def initialize
          @filters = []
        end

        # Adds a filter
        #
        # @param name [Symbol] Filter name
        # @param options [Hash] Filter options
        # @option options [Symbol] :type Filter type (:text, :select, :toggle, :date, :date_range, :number)
        # @option options [String] :label Display label
        # @option options [String] :placeholder Placeholder text
        # @option options [Array] :options Options for select filters
        # @option options [Symbol] :field Database field to filter (defaults to name)
        # @return [void]
        def filter(name, **options)
          @filters << FilterDefinition.new(
            name: name,
            type: options[:type] || :text,
            label: options[:label] || name.to_s.humanize,
            placeholder: options[:placeholder],
            options: options[:options],
            field: options[:field] || name
          )
        end
      end

      # Filter definition
      FilterDefinition = Struct.new(:name, :type, :label, :placeholder, :options, :field, keyword_init: true)

      # Stats builder for index view
      class StatsBuilder
        attr_reader :stats

        def initialize
          @stats = []
        end

        # Adds a stat
        #
        # @param name [Symbol] Stat name
        # @param calculator [Proc] Proc to calculate the value
        # @param options [Hash] Stat options
        # @option options [Symbol] :color Color for the stat
        # @return [void]
        def stat(name, calculator, **options)
          @stats << StatDefinition.new(
            name: name,
            calculator: calculator,
            color: options[:color]
          )
        end
      end

      # Stat definition
      StatDefinition = Struct.new(:name, :calculator, :color, keyword_init: true)

      # Form configuration
      class FormConfig
        attr_reader :fields_list

        def initialize
          @fields_list = []
        end

        # Adds a field
        #
        # @param name [Symbol] Field name
        # @param options [Hash] Field options
        # @option options [Symbol] :type Field type (:text, :textarea, :select, :toggle, :searchable_select, :tags, :multi_select, :image, :attachment, :markdown, :json, etc.)
        # @option options [Boolean] :required Whether field is required
        # @option options [String] :label Display label
        # @option options [String] :help Help text
        # @option options [String] :placeholder Placeholder text
        # @option options [Proc, Array, String] :collection Options for select fields or search URL
        # @option options [String, Symbol, Boolean] :create_url URL for creating new options (or true for inline creation)
        # @option options [String] :accept Accept attribute for file fields (e.g., "image/*")
        # @option options [Integer] :rows Rows for textarea
        # @option options [Boolean] :multiple Whether to allow multiple selections
        # @option options [Boolean] :creatable Whether new options can be created inline
        # @option options [Boolean] :preview Whether to show file preview
        # @option options [Hash] :variants Image variant options for preview
        # @return [void]
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

        # Groups fields in a section
        #
        # @param title [String] Section title
        # @param options [Hash] Section options
        # @yield Block for section fields
        # @return [void]
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

        # Groups fields in a row (grid)
        #
        # @param options [Hash] Row options
        # @option options [Integer] :cols Number of columns
        # @yield Block for row fields
        # @return [void]
        def row(**options, &block)
          @fields_list << RowDefinition.new(cols: options[:cols] || 2)
          instance_eval(&block) if block_given?
          @fields_list << RowEnd.new
        end
      end

      # Field definition
      FieldDefinition = Struct.new(
        :name, :type, :required, :label, :help, :placeholder,
        :collection, :create_url, :accept, :rows, :readonly,
        :if_condition, :unless_condition, :multiple, :creatable,
        :preview, :variants, :label_color, :label_size,
        keyword_init: true
      )

      # Section definition for grouping fields
      SectionDefinition = Struct.new(:title, :description, :collapsible, :collapsed, keyword_init: true)
      SectionEnd = Class.new

      # Row definition for grid layout
      RowDefinition = Struct.new(:cols, keyword_init: true)
      RowEnd = Class.new

      # Show page configuration
      class ShowConfig
        attr_reader :sidebar_sections, :main_sections

        def initialize
          @sidebar_sections = []
          @main_sections = []
        end

        # Legacy method for backward compatibility - adds to main by default
        #
        # @param name [Symbol] Section name
        # @param options [Hash] Section options
        # @return [void]
        def section(name, **options)
          @main_sections << build_section(name, options)
        end

        # Configures sidebar sections (left column, typically for metadata)
        #
        # @yield Block for sidebar configuration
        # @return [void]
        def sidebar(&block)
          @current_target = :sidebar
          instance_eval(&block) if block_given?
          @current_target = nil
        end

        # Configures main content sections (right column, typically for content/associations)
        #
        # @yield Block for main content configuration
        # @return [void]
        def main(&block)
          @current_target = :main
          instance_eval(&block) if block_given?
          @current_target = nil
        end

        # Adds a panel to the current target (sidebar or main)
        #
        # @param name [Symbol] Panel name
        # @param options [Hash] Panel options
        # @option options [Array<Symbol>] :fields Fields to display
        # @option options [Symbol] :association Association to display
        # @option options [Integer] :limit Limit for associations
        # @option options [Symbol] :render Custom renderer
        # @option options [Symbol] :display Display type for associations (:list, :table, :cards)
        # @option options [Array<Symbol>] :columns Columns for table display
        # @option options [String] :link_to Path helper for linking to associated records
        # @option options [Symbol] :resource Resource class for associated records
        # @return [void]
        def panel(name, **options)
          section_def = build_section(name, options)

          case @current_target
          when :sidebar
            @sidebar_sections << section_def
          else
            @main_sections << section_def
          end
        end

        # Returns all sections (for backward compatibility)
        #
        # @return [Array<ShowSectionDefinition>]
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

      # Show section definition
      ShowSectionDefinition = Struct.new(
        :name, :fields, :association, :limit, :render, :title,
        :display, :columns, :link_to, :resource, :paginate, :per_page, :collapsible, :collapsed,
        keyword_init: true
      )

      # Actions configuration
      class ActionsConfig
        attr_reader :member_actions, :collection_actions, :bulk_actions

        def initialize
          @member_actions = []
          @collection_actions = []
          @bulk_actions = []
        end

        # Adds a member action (operates on single record)
        #
        # @param name [Symbol] Action name
        # @param options [Hash] Action options
        # @option options [Symbol] :method HTTP method (:post, :patch, :delete)
        # @option options [String] :confirm Confirmation message
        # @option options [Symbol] :type Action type (:button, :link, :modal)
        # @option options [String] :label Display label
        # @option options [String] :icon Icon name
        # @option options [Symbol] :color Color scheme
        # @return [void]
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

        # Adds a collection action (operates on collection)
        #
        # @param name [Symbol] Action name
        # @param options [Hash] Action options (same as action)
        # @return [void]
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

        # Adds a bulk action (operates on selected records)
        #
        # @param name [Symbol] Action name
        # @param options [Hash] Action options (same as action)
        # @return [void]
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

      # Action definition
      ActionDefinition = Struct.new(
        :name, :method, :confirm, :type, :label, :icon, :color,
        :if_condition, :unless_condition,
        keyword_init: true
      )
    end
  end
end
