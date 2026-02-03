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

        executor = Admin::Base::ActionExecutor.new(resource_config, action_name, admin_suite_actor)
        result = executor.execute_member(@resource, params.to_unsafe_h)

        if result.success?
          redirect_to resource_url(@resource), notice: result.message
        else
          redirect_to resource_url(@resource), alert: result.message
        end
      end

      # POST /internal/developer/:portal/:resource_name/:id/toggle
      def toggle
        field = toggle_field_param

        unless field
          respond_to do |format|
            format.turbo_stream { head :unprocessable_entity }
            format.html { redirect_to resource_url(@resource), alert: "Toggle field is missing." }
          end
          return
        end

        unless toggleable_fields.include?(field)
          respond_to do |format|
            format.turbo_stream { head :unprocessable_entity }
            format.html { redirect_to resource_url(@resource), alert: "Toggle field is not allowed." }
          end
          return
        end

        current_value = !!@resource.public_send(field)
        @resource.update!(field => !current_value)

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              dom_id(@resource, :toggle),
              partial: "internal/developer/shared/toggle_cell",
              locals: { record: @resource, field: field }
            )
          end
          format.html { redirect_to resource_url(@resource), notice: "#{resource_config.human_name} updated." }
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
        executor = Admin::Base::ActionExecutor.new(resource_config, action_name, admin_suite_actor)
        result = executor.execute_bulk(records, params.to_unsafe_h)

        if result.success?
          redirect_to collection_url, notice: result.message
        else
          redirect_to collection_url, alert: result.message
        end
      end

      protected

      # Resolves the resource configuration.
      #
      # For normal resource controllers (e.g. `Internal::Developer::Ops::UsersController`),
      # `BaseController#resource_config` uses `controller_name`.
      #
      # For the generic action routes:
      # `/internal/developer/:portal/:resource_name/:id/execute_action/:action_name`,
      # we need to resolve based on `params[:resource_name]`.
      #
      # @return [Class, nil]
      def resource_config
        return super unless params[:resource_name].present?

        resource_name = params[:resource_name].to_s.singularize.camelize
        "Admin::Resources::#{resource_name}Resource".constantize
      rescue NameError
        nil
      end

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
        return base_collection unless resource_config&.index_config

        Admin::Base::FilterBuilder.new(resource_config, params).apply(base_collection)
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
        permitted_fields = []
        array_fields = []

        resource_config&.form_config&.fields_list&.each do |field|
          next if field.is_a?(Admin::Base::Resource::SectionDefinition) ||
                  field.is_a?(Admin::Base::Resource::SectionEnd) ||
                  field.is_a?(Admin::Base::Resource::RowDefinition) ||
                  field.is_a?(Admin::Base::Resource::RowEnd)

          # Tags and multi-select fields need to be permitted as arrays
          if field.type == :tags || field.type == :multi_select
            array_fields << { field.name => [] }
            # Also permit tag_list for :tags type
            array_fields << { tag_list: [] } if field.type == :tags && field.name != :tag_list
          else
            permitted_fields << field.name
          end
        end

        # Handle STI: the form is built from the concrete record class (e.g. Ai::AssistantSystemPrompt)
        # but the resource config may be the base class (e.g. Ai::LlmPrompt).
        param_keys = [
          (@resource&.class&.model_name&.param_key if defined?(@resource)),
          resource_class.model_name.param_key
        ].compact.uniq

        key = param_keys.find { |k| params.key?(k) }
        params.require(key).permit(permitted_fields + array_fields)
      end

      def toggle_field_param
        field = params[:field].presence
        field&.to_sym
      end

      def toggleable_fields
        return [] unless resource_config&.index_config&.columns_list

        resource_config.index_config.columns_list.filter_map do |column|
          next unless column.type == :toggle

          (column.toggle_field || column.name).to_sym
        end
      end

      # Returns the URL for a resource
      #
      # @param record [ActiveRecord::Base] Record
      # @return [String]
      def resource_url(record)
        url_for(controller: resource_controller_path, action: :show, id: record.to_param)
      end

      # Returns the URL for the collection
      #
      # @return [String]
      def collection_url
        url_for(controller: resource_controller_path, action: :index)
      end

      # Returns the correct controller path for redirects when using generic routes.
      #
      # @return [String]
      def resource_controller_path
        if params[:portal].present? && params[:resource_name].present?
          "/internal/developer/#{params[:portal]}/#{params[:resource_name]}"
        else
          controller_path
        end
      end
    end
  end
end
