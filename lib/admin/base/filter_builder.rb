# frozen_string_literal: true

module Admin
  module Base
    class FilterBuilder
      # Matches the index search box's existing floor: below this,
      # `apply_search` leaves the scope untouched rather than emitting a
      # near-useless single/double-character ILIKE. `search_predicate`
      # (below) is where this now lives, since it's shared with
      # `ResourcesController#search`.
      MIN_SEARCH_LENGTH = 3

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

      # Builds the shared ILIKE-over-searchable_fields predicate -- the exact
      # logic `apply_search` below uses for the index's own search box --
      # extracted so `ResourcesController#search` (the searchable_select
      # endpoint) can reuse it verbatim instead of growing a second,
      # divergent search path over the same whitelist.
      #
      # The term is always returned as a value to be bound (`"%term%"`),
      # never interpolated into the SQL text -- only the (whitelisted) field
      # *names* from `index_config.searchable_fields` go into the conditions
      # string, exactly as `apply_search` has always built it. That keeps
      # this safe against SQL metacharacters in `term`: whatever a caller
      # passes ends up as a single bound parameter, not part of the query
      # text.
      #
      # Returns nil when no predicate should be applied at all: no index
      # config, no declared `searchable` fields, a blank term, or a term
      # shorter than `MIN_SEARCH_LENGTH`. What a nil predicate *means* is
      # left to the caller -- `apply_search` treats it as "don't filter"
      # (falls back to the unfiltered scope, correct for an index filter
      # box), while `ResourcesController#search` treats it as "no results"
      # (correct for a raw JSON data endpoint, which must never hand back
      # the unfiltered table just because the query was blank/too short or
      # the resource has no searchable fields to check).
      #
      # @param index_config [Admin::Base::Resource::IndexConfig, nil]
      # @param term [String, nil]
      # @return [Array(String, String), nil] [sql_conditions, "%term%"]
      def self.search_predicate(index_config, term)
        return nil if index_config.nil?
        return nil if term.blank?
        return nil if index_config.searchable_fields.empty?
        return nil if term.to_s.length < MIN_SEARCH_LENGTH

        conditions = index_config.searchable_fields.map { |field| "#{field} ILIKE :search" }.join(" OR ")
        [ conditions, "%#{term}%" ]
      end

      private

      def index_config
        @resource_class.index_config
      end

      def apply_search(scope)
        return scope unless index_config

        predicate = self.class.search_predicate(index_config, params[:search])
        return scope unless predicate

        conditions, search_term = predicate
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

        value = params[filter.name].presence
        value = filter.default if value.blank? && filter.respond_to?(:default)
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
