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
      field ||= toggleable_fields.first if toggleable_fields.one?
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
            dom_id(@resource, "#{field}_toggle"),
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
      klass = resource_class
      id = params[:id].to_s
      columns = klass.column_names

      # Prevent ActiveRecord from coercing UUID-ish params like "2ce3-..."
      # into integer ids (e.g., 2) for integer primary keys.
      if non_numeric_id_for_numeric_primary_key?(klass, id)
        @resource = find_friendly_resource!(klass, id, columns)
        return
      end

      @resource = klass.find(id)
    rescue ActiveRecord::RecordNotFound
      @resource = find_friendly_resource!(klass, id, columns)
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
      return [] unless resource_config

      index_fields = resource_config.index_config&.columns_list&.filter_map do |col|
        next unless col.type == :toggle

        (col.toggle_field || col.name).to_sym
      end || []

      form_fields = resource_config.form_config&.fields_list&.filter_map do |field|
        next unless field.is_a?(Admin::Base::Resource::FieldDefinition)
        next unless field.type == :toggle

        field.name.to_sym
      end || []

      (index_fields + form_fields).uniq
    end

    def resource_url(record)
      resource_path(portal: current_portal, resource_name: resource_name, id: record.to_param)
    end

    def collection_url
      resources_path(portal: current_portal, resource_name: resource_name)
    end

    def find_friendly_resource!(klass, id, columns = klass.column_names)
      if columns.include?("slug")
        record = klass.find_by(slug: id)
        return record if record
      end

      if columns.include?("uuid")
        record = klass.find_by(uuid: id)
        return record if record
      end

      if columns.include?("token")
        record = klass.find_by(token: id)
        return record if record
      end

      raise ActiveRecord::RecordNotFound
    end

    def non_numeric_id_for_numeric_primary_key?(klass, id)
      primary_key = klass.primary_key.to_s
      return false if primary_key.blank?

      pk_type = klass.columns_hash[primary_key]&.type
      numeric_pk = %i[integer bigint].include?(pk_type)
      numeric_pk && id !~ /\A\d+\z/
    end
  end
end
