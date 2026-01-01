# frozen_string_literal: true

module Internal
  module Developer
    # Generic resources controller for the admin framework
    #
    # Provides CRUD operations for any resource defined with Admin::Base::Resource.
    # Can be inherited by specific resource controllers or used directly.
    class ResourcesController < BaseController
      include Pagy::Backend
      include Pagy::Frontend
      include Rails.application.routes.url_helpers

      before_action :set_resource, if: -> { params[:id].present? && action_name != "index" && action_name != "new" && action_name != "create" }

      helper_method :resource_class, :collection, :resource

      protected

      # Override view prefixes to also look in resources/ folder for shared views
      # This allows specific controllers to have their own views, falling back to shared ones
      def _prefixes
        @_prefixes ||= super + [ "internal/developer/resources" ]
      end

      public

      # GET /internal/developer/:resources
      def index
        @stats = calculate_stats if resource_config&.index_config&.stats_list&.any?
        @pagy, @collection = paginate_collection(filtered_collection)
      end

      # GET /internal/developer/:resources/:id
      def show
      end

      # GET /internal/developer/:resources/new
      def new
        @resource = resource_class.new
      end

      # GET /internal/developer/:resources/:id/edit
      def edit
      end

      # POST /internal/developer/:resources
      def create
        @resource = resource_class.new(resource_params)

        if @resource.save
          redirect_to resource_url(@resource), notice: "#{resource_config.human_name} was successfully created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /internal/developer/:resources/:id
      def update
        if @resource.update(resource_params)
          redirect_to resource_url(@resource), notice: "#{resource_config.human_name} was successfully updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /internal/developer/:resources/:id
      def destroy
        @resource.destroy!
        redirect_to collection_url, notice: "#{resource_config.human_name} was successfully deleted."
      end

      # POST /internal/developer/:resources/:id/execute_action/:action_name
      def execute_action
        action_name = params[:action_name].to_sym
        action_def = find_action(action_name)

        if action_def.nil?
          redirect_to resource_url(@resource), alert: "Action not found."
          return
        end

        executor = Admin::Base::ActionExecutor.new(resource_config, @resource, action_name)
        result = executor.execute

        if result.success?
          redirect_to resource_url(@resource), notice: result.message
        else
          redirect_to resource_url(@resource), alert: result.message
        end
      end

      # POST /internal/developer/:resources/bulk_action/:action_name
      def bulk_action
        action_name = params[:action_name].to_sym
        ids = params[:ids] || []

        if ids.empty?
          redirect_to collection_url, alert: "No items selected."
          return
        end

        model = resource_class
        if ids.all? { |id| uuid_param?(id) } && model.column_names.include?("uuid")
          records = model.where(uuid: ids)
        else
          records = model.where(id: ids)
        end
        executor = Admin::Base::ActionExecutor.new(resource_config, records, action_name, bulk: true)
        result = executor.execute

        if result.success?
          redirect_to collection_url, notice: result.message
        else
          redirect_to collection_url, alert: result.message
        end
      end

      protected

      # Returns the model class for the resource
      #
      # @return [Class]
      def resource_class
        resource_config&.model_class || controller_name.classify.constantize
      end

      # Returns the current resource instance
      #
      # @return [ActiveRecord::Base]
      def resource
        @resource
      end

      # Returns the current collection
      #
      # @return [ActiveRecord::Relation]
      def collection
        @collection
      end

      private

      # Sets the resource from params
      #
      # @return [void]
      def set_resource
        model = resource_config.model_class
        @resource = find_resource(model, params[:id])
      end

      def find_resource(model, param)
        if uuid_param?(param) && model.column_names.include?("uuid")
          model.find_by!(uuid: param)
        else
          model.find(param)
        end
      end

      def uuid_param?(value)
        value.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      end

      # Returns the base collection with any default scopes
      #
      # @return [ActiveRecord::Relation]
      def base_collection
        resource_config.model_class.all
      end

      # Applies filters and search to the collection
      #
      # @return [ActiveRecord::Relation]
      def filtered_collection
        scope = base_collection

        # Apply search (minimum 3 characters required)
        if params[:search].present? && params[:search].length >= 3 && resource_config&.index_config&.searchable_fields&.any?
          search_conditions = resource_config.index_config.searchable_fields.map do |field|
            "#{field} ILIKE :search"
          end.join(" OR ")

          scope = scope.where(search_conditions, search: "%#{params[:search]}%")
        end

        # Apply filters (skip reserved params: search, sort, direction)
        resource_config&.index_config&.filters_list&.each do |filter|
          next if %i[search sort direction].include?(filter.name)
          next unless params[filter.name].present?

          scope = apply_filter(scope, filter, params[filter.name])
        end

        # Apply sorting
        sort_field = params[:sort] || resource_config&.index_config&.default_sort
        sort_direction = params[:direction] == "desc" ? :desc : :asc

        if sort_field.present?
          scope = scope.order(sort_field => sort_direction)
        else
          scope = scope.order(created_at: :desc)
        end

        scope
      end

      # Applies a single filter to the collection
      #
      # @param scope [ActiveRecord::Relation] Current scope
      # @param filter [FilterDefinition] Filter definition
      # @param value [String] Filter value
      # @return [ActiveRecord::Relation]
      def apply_filter(scope, filter, value)
        field = filter.field

        case filter.type
        when :select, :toggle
          scope.where(field => value)
        when :date
          scope.where("DATE(#{field}) = ?", value)
        when :date_range
          if value[:start].present? && value[:end].present?
            scope.where(field => value[:start]..value[:end])
          elsif value[:start].present?
            scope.where("#{field} >= ?", value[:start])
          elsif value[:end].present?
            scope.where("#{field} <= ?", value[:end])
          else
            scope
          end
        else
          scope.where("#{field} ILIKE ?", "%#{value}%")
        end
      end

      # Paginates the collection
      #
      # @param scope [ActiveRecord::Relation] Collection to paginate
      # @return [Array<Pagy, ActiveRecord::Relation>]
      def paginate_collection(scope)
        per_page = resource_config&.index_config&.per_page || 25
        pagy(scope, items: per_page)
      end

      # Calculates stats for the index view
      #
      # @return [Array<Hash>]
      def calculate_stats
        resource_config.index_config.stats_list.map do |stat_def|
          # Stats procs don't take arguments - they query directly
          value = begin
            stat_def.calculator.call
          rescue => e
            Rails.logger.error("Error calculating stat #{stat_def.name}: #{e.message}")
            "N/A"
          end

          {
            name: stat_def.name.to_s.humanize,
            value: value,
            color: stat_def.color
          }
        end
      end

      # Finds an action definition by name
      #
      # @param name [Symbol] Action name
      # @return [ActionDefinition, nil]
      def find_action(name)
        resource_config&.actions_config&.member_actions&.find { |a| a.name == name }
      end

      # Returns permitted parameters based on form configuration
      #
      # @return [ActionController::Parameters]
      def resource_params
        permitted_fields = resource_config&.form_config&.fields_list&.map do |field|
          next if field.is_a?(Admin::Base::Resource::SectionDefinition) ||
                  field.is_a?(Admin::Base::Resource::SectionEnd) ||
                  field.is_a?(Admin::Base::Resource::RowDefinition) ||
                  field.is_a?(Admin::Base::Resource::RowEnd)

          field.name
        end&.compact || []

        # Handle STI: the form is built from the concrete record class (e.g. Ai::AssistantSystemPrompt)
        # but the resource config may be the base class (e.g. Ai::LlmPrompt).
        param_keys = [
          (@resource&.class&.model_name&.param_key if defined?(@resource)),
          resource_class.model_name.param_key
        ].compact.uniq

        key = param_keys.find { |k| params.key?(k) }
        params.require(key).permit(permitted_fields)
      end

      # Returns the URL for a resource
      #
      # @param record [ActiveRecord::Base] Record
      # @return [String]
      def resource_url(record)
        url_for(controller: controller_path, action: :show, id: record.to_param)
      end

      # Returns the URL for the collection
      #
      # @return [String]
      def collection_url
        url_for(controller: controller_path, action: :index)
      end
    end
  end
end
