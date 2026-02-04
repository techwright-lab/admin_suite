# frozen_string_literal: true

module Admin
  module Base
    class FilterBuilder
      attr_reader :resource_class, :params

      def initialize(resource_class, params)
        @resource_class = resource_class
        @params = params
      end

      def apply(scope)
        scope = apply_search(scope)
        scope = apply_filters(scope)
        scope = apply_sort(scope)
        scope
      end

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

      def apply_search(scope)
        return scope unless index_config
        return scope if params[:search].blank?
        return scope if index_config.searchable_fields.empty?
        return scope if params[:search].to_s.length < 3

        search_term = "%#{params[:search]}%"
        conditions = index_config.searchable_fields.map { |field| "#{field} ILIKE :search" }.join(" OR ")
        scope.where(conditions, search: search_term)
      end

      def apply_filters(scope)
        return scope unless index_config

        index_config.filters_list.each do |filter|
          scope = apply_filter(scope, filter)
        end
        scope
      end

      def apply_filter(scope, filter)
        # Some "filters" in the UI are really just controls (e.g. sort dropdown).
        # They are handled elsewhere (`apply_sort`) and must not be turned into SQL.
        return scope if %i[sort sort_direction direction page search].include?(filter.name.to_sym)

        value = params[filter.name]
        return scope if value.blank?

        if filter.respond_to?(:apply) && filter.apply.present?
          return apply_custom_filter(scope, filter.apply, value)
        end

        case filter.type
        when :text, :search
          scope.where("#{filter.field} ILIKE ?", "%#{value}%")
        when :select
          scope.where(filter.field => value)
        when :toggle, :boolean
          bool_value = ActiveModel::Type::Boolean.new.cast(value)
          scope.where(filter.field => bool_value)
        when :number
          scope.where(filter.field => value.to_i)
        when :date
          date = Date.parse(value) rescue nil
          return scope unless date
          scope.where(filter.field => date.all_day)
        when :date_range
          from_date = params["#{filter.name}_from"].presence
          to_date = params["#{filter.name}_to"].presence
          scope = scope.where("#{filter.field} >= ?", Date.parse(from_date)) if from_date.present?
          scope = scope.where("#{filter.field} <= ?", Date.parse(to_date).end_of_day) if to_date.present?
          scope
        when :association
          scope.where("#{filter.field}_id" => value)
        else
          scope
        end
      end

      def apply_custom_filter(scope, filter_proc, value)
        filter_proc.arity == 2 ? filter_proc.call(scope, value) : filter_proc.call(scope, value, params)
      end

      def apply_sort(scope)
        return scope unless index_config

        sort_field = params[:sort].presence || index_config.default_sort
        return scope unless sort_field

        unless index_config.sortable_fields.include?(sort_field.to_sym)
          sort_field = index_config.default_sort
        end
        return scope unless sort_field

        direction_param = params[:sort_direction].presence || params[:direction].presence
        direction =
          if direction_param.present?
            direction_param.to_sym == :desc ? :desc : :asc
          else
            (index_config.default_sort_direction || :desc).to_sym
          end

        scope.order(sort_field => direction)
      end
    end
  end
end
