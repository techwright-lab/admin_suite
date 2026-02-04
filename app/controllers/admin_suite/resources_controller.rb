# frozen_string_literal: true

module AdminSuite
  class ResourcesController < ApplicationController
    include Pagy::Backend
    include Pagy::Frontend

    before_action :set_resource, if: -> { params[:id].present? && !%w[index new create].include?(action_name) }

    helper_method :resource_config, :resource_class, :resource, :collection, :current_portal, :resource_name

    # GET /:portal/:resource_name
    def index
      @stats = calculate_stats if resource_config&.index_config&.stats_list&.any?
      @pagy, @collection = paginate_collection(filtered_collection)
    end

    # GET /:portal/:resource_name/:id
    def show
    end

    # GET /:portal/:resource_name/new
    def new
      @resource = resource_class.new
    end

    # GET /:portal/:resource_name/:id/edit
    def edit
    end

    # POST /:portal/:resource_name
    def create
      @resource = resource_class.new(resource_params)
      if @resource.save
        redirect_to resource_url(@resource), notice: "#{resource_config.human_name} was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /:portal/:resource_name/:id
    def update
      if @resource.update(resource_params)
        redirect_to resource_url(@resource), notice: "#{resource_config.human_name} was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /:portal/:resource_name/:id
    def destroy
      @resource.destroy!
      redirect_to collection_url, notice: "#{resource_config.human_name} was successfully deleted.", status: :see_other
    end

    # POST /:portal/:resource_name/:id/execute_action/:action_name
    def execute_action
      action = params[:action_name].to_s.to_sym
      action_def = find_action(action)
      unless action_def
        redirect_to resource_url(@resource), alert: "Action not found."
        return
      end

      executor = Admin::Base::ActionExecutor.new(resource_config, action, admin_suite_actor)
      result = executor.execute_member(@resource, params.to_unsafe_h)

      if result.success?
        redirect_to resource_url(@resource), notice: result.message
      else
        redirect_to resource_url(@resource), alert: result.message
      end
    end

    # POST /:portal/:resource_name/bulk_action/:action_name
    def bulk_action
      action = params[:action_name].to_s.to_sym
      ids = params[:ids] || []
      if ids.empty?
        redirect_to collection_url, alert: "No items selected."
        return
      end

      model = resource_class
      records = model.where(id: ids)
      executor = Admin::Base::ActionExecutor.new(resource_config, action, admin_suite_actor)
      result = executor.execute_bulk(records, params.to_unsafe_h)

      if result.success?
        redirect_to collection_url, notice: result.message
      else
        redirect_to collection_url, alert: result.message
      end
    end

    # POST /:portal/:resource_name/:id/toggle
    def toggle
      field = params[:field].presence&.to_sym
      unless field
        head :unprocessable_entity
        return
      end

      unless toggleable_fields.include?(field)
        head :unprocessable_entity
        return
      end

      current_value = !!@resource.public_send(field)
      @resource.update!(field => !current_value)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@resource, :toggle),
            partial: "admin_suite/shared/toggle_cell",
            locals: { record: @resource, field: field, toggle_url: resource_toggle_path(portal: current_portal, resource_name: resource_name, id: @resource.to_param, field: field) }
          )
        end
        format.html { redirect_to resource_url(@resource), notice: "#{resource_config.human_name} updated." }
      end
    end

    private

    def current_portal
      params[:portal].to_s.presence&.to_sym
    end

    def resource_name
      params[:resource_name].to_s
    end

    def resource_config
      ensure_resources_loaded!
      klass_name = resource_name.singularize.camelize
      "Admin::Resources::#{klass_name}Resource".constantize
    rescue NameError
      nil
    end

    def resource_class
      resource_config&.model_class || resource_name.classify.constantize
    end

    def set_resource
      @resource = resource_class.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      # Support "friendly" params (e.g. slugged records) without requiring host apps
      # to change their model primary keys.
      id = params[:id].to_s
      columns = resource_class.column_names

      @resource =
        if columns.include?("slug")
          resource_class.find_by!(slug: id)
        elsif columns.include?("uuid")
          resource_class.find_by!(uuid: id)
        elsif columns.include?("token")
          resource_class.find_by!(token: id)
        else
          raise
        end
    end

    def resource
      @resource
    end

    def collection
      @collection
    end

    def filtered_collection
      return resource_class.all unless resource_config&.index_config

      Admin::Base::FilterBuilder.new(resource_config, params).apply(resource_class.all)
    end

    def paginate_collection(scope)
      per_page = resource_config&.index_config&.per_page || 25
      pagy(scope, items: per_page)
    end

    def calculate_stats
      resource_config.index_config.stats_list.map do |stat_def|
        value =
          begin
            stat_def.calculator.call
          rescue StandardError
            "N/A"
          end
        { name: stat_def.name.to_s.humanize, value: value, color: stat_def.color }
      end
    end

    def find_action(name)
      resource_config&.actions_config&.member_actions&.find { |a| a.name == name }
    end

    def resource_params
      permitted_fields = []
      array_fields = []

      resource_config&.form_config&.fields_list&.each do |field|
        next unless field.is_a?(Admin::Base::Resource::FieldDefinition)

        if field.type == :tags || field.type == :multi_select
          array_fields << { field.name => [] }
          array_fields << { tag_list: [] } if field.type == :tags && field.name != :tag_list
        else
          permitted_fields << field.name
        end
      end

      key = resource_class.model_name.param_key
      params.require(key).permit(permitted_fields + array_fields)
    end

    def toggleable_fields
      return [] unless resource_config&.index_config&.columns_list

      resource_config.index_config.columns_list.filter_map do |col|
        next unless col.type == :toggle

        (col.toggle_field || col.name).to_sym
      end
    end

    def resource_url(record)
      resource_path(portal: current_portal, resource_name: resource_name, id: record.to_param)
    end

    def collection_url
      resources_path(portal: current_portal, resource_name: resource_name)
    end
  end
end
