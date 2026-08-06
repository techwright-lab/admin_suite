# frozen_string_literal: true

module AdminSuite
  # The one place an index-style query is built.
  #
  # Both the web index action and the MCP `list_records` tool go through
  # this object, so the two surfaces cannot disagree about what a filter,
  # a sort, or a page size means.
  class Query
    MAX_PAGE_SIZE = 100

    def initialize(resource_config:, params: {}, max_page_size: MAX_PAGE_SIZE)
      @resource_config = resource_config
      @params = params || {}
      @max_page_size = max_page_size
    end

    def scope
      @scope ||= apply_includes(filtered)
    end

    def per_page
      @per_page ||= clamp(@params[:per_page] || @params["per_page"])
    end

    private

    def index_config = @resource_config&.index_config
    def model_class = @resource_config.model_class

    def filtered
      return model_class.all unless index_config

      Admin::Base::FilterBuilder.new(@resource_config, @params).apply(model_class.all)
    end

    # Applies the index's `includes:` DSL option when the relation supports
    # it. Invalid associations degrade to an unoptimized working query.
    def apply_includes(relation)
      list = index_config&.includes_list
      return relation if list.blank?
      return relation unless relation.respond_to?(:includes)

      relation.includes(*list)
    rescue StandardError => e
      Rails.logger&.warn(
        "AdminSuite: #{model_class}'s index `includes(#{list.inspect})` raised " \
        "#{e.class}: #{e.message}; rendering the index without eager loading."
      )
      relation
    end

    def clamp(requested)
      fallback = index_config&.per_page || 25
      value = Integer(requested)
      return fallback if value <= 0

      value.clamp(..@max_page_size)
    rescue ArgumentError, TypeError
      fallback
    end
  end
end
