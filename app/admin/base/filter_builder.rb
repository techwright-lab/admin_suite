# frozen_string_literal: true

module Admin
  module Base
    # Builds filtered queries from resource filter definitions and params
    #
    # Takes a resource's filter configuration and applies it to a scope
    # based on the current request parameters.
    #
    # @example
    #   filter_builder = Admin::Base::FilterBuilder.new(CompanyResource, params)
    #   filtered_scope = filter_builder.apply(Company.all)
    class FilterBuilder
      attr_reader :resource_class, :params

      # Initializes the filter builder
      #
      # @param resource_class [Class] The resource class with filter definitions
      # @param params [ActionController::Parameters] Request parameters
      def initialize(resource_class, params)
        @resource_class = resource_class
        @params = params
      end

      # Applies all filters to a scope
      #
      # @param scope [ActiveRecord::Relation] The base scope
      # @return [ActiveRecord::Relation] Filtered scope
      def apply(scope)
        scope = apply_search(scope)
        scope = apply_filters(scope)
        scope = apply_sort(scope)
        scope
      end

      # Returns the current filter parameters
      #
      # @return [Hash]
      def filter_params
        return {} unless index_config

        permitted_keys = [ :search, :sort, :sort_direction, :page ]
        permitted_keys += index_config.filters_list.map(&:name)

        params.permit(*permitted_keys).to_h.symbolize_keys
      end

      private

      def index_config
        @resource_class.index_config
      end

      # Applies search filter
      #
      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation]
      def apply_search(scope)
        return scope unless index_config
        return scope if params[:search].blank?
        return scope if index_config.searchable_fields.empty?

        search_term = "%#{params[:search]}%"
        conditions = index_config.searchable_fields.map do |field|
          "#{field} ILIKE :search"
        end.join(" OR ")

        scope.where(conditions, search: search_term)
      end

      # Applies individual filters
      #
      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation]
      def apply_filters(scope)
        return scope unless index_config

        index_config.filters_list.each do |filter|
          scope = apply_filter(scope, filter)
        end

        scope
      end

      # Applies a single filter
      #
      # @param scope [ActiveRecord::Relation]
      # @param filter [FilterDefinition]
      # @return [ActiveRecord::Relation]
      def apply_filter(scope, filter)
        value = params[filter.name]
        return scope if value.blank?

        case filter.type
        when :text, :search
          apply_text_filter(scope, filter, value)
        when :select
          apply_select_filter(scope, filter, value)
        when :toggle, :boolean
          apply_boolean_filter(scope, filter, value)
        when :number
          apply_number_filter(scope, filter, value)
        when :date
          apply_date_filter(scope, filter, value)
        when :date_range
          apply_date_range_filter(scope, filter, value)
        when :association
          apply_association_filter(scope, filter, value)
        else
          scope
        end
      end

      def apply_text_filter(scope, filter, value)
        scope.where("#{filter.field} ILIKE ?", "%#{value}%")
      end

      def apply_select_filter(scope, filter, value)
        scope.where(filter.field => value)
      end

      def apply_boolean_filter(scope, filter, value)
        bool_value = ActiveModel::Type::Boolean.new.cast(value)
        scope.where(filter.field => bool_value)
      end

      def apply_number_filter(scope, filter, value)
        scope.where(filter.field => value.to_i)
      end

      def apply_date_filter(scope, filter, value)
        date = Date.parse(value) rescue nil
        return scope unless date

        scope.where(filter.field => date.all_day)
      end

      def apply_date_range_filter(scope, filter, value)
        from_date = params["#{filter.name}_from"].presence
        to_date = params["#{filter.name}_to"].presence

        if from_date.present?
          scope = scope.where("#{filter.field} >= ?", Date.parse(from_date))
        end

        if to_date.present?
          scope = scope.where("#{filter.field} <= ?", Date.parse(to_date).end_of_day)
        end

        scope
      end

      def apply_association_filter(scope, filter, value)
        scope.where("#{filter.field}_id" => value)
      end

      # Applies sort
      #
      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation]
      def apply_sort(scope)
        return scope unless index_config

        sort_field = params[:sort].presence || index_config.default_sort
        return scope unless sort_field

        # Validate sort field is allowed
        unless index_config.sortable_fields.include?(sort_field.to_sym)
          sort_field = index_config.default_sort
        end

        return scope unless sort_field

        direction = params[:sort_direction]&.to_sym == :desc ? :desc : :asc
        scope.order(sort_field => direction)
      end
    end
  end
end
