# frozen_string_literal: true

module Admin
  # Controller for managing LLM provider configurations in the admin panel
  #
  # Provides full CRUD for LLM provider configs with test provider action
  class LlmProviderConfigsController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable
    include Concerns::StatsCalculator

    PER_PAGE = 20

    before_action :set_provider_config, only: [ :show, :edit, :update, :destroy, :test_provider ]

    # GET /admin/llm_provider_configs
    #
    # Lists provider configs with filtering
    def index
      @pagy, @provider_configs = paginate(filtered_provider_configs)
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/llm_provider_configs/:id
    #
    # Shows provider config details
    def show
    end

    # GET /admin/llm_provider_configs/new
    def new
      @provider_config = LlmProviderConfig.new(
        enabled: true,
        priority: 0,
        max_tokens: 4096,
        temperature: 0.0,
        settings: {}
      )
    end

    # POST /admin/llm_provider_configs
    def create
      @provider_config = LlmProviderConfig.new(provider_config_params)

      if @provider_config.save
        redirect_to admin_llm_provider_config_path(@provider_config), notice: "LLM provider config created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/llm_provider_configs/:id/edit
    def edit
    end

    # PATCH/PUT /admin/llm_provider_configs/:id
    def update
      if @provider_config.update(provider_config_params)
        redirect_to admin_llm_provider_config_path(@provider_config), notice: "LLM provider config updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/llm_provider_configs/:id
    def destroy
      @provider_config.destroy
      redirect_to admin_llm_provider_configs_path, notice: "LLM provider config deleted.", status: :see_other
    end

    # POST /admin/llm_provider_configs/:id/test_provider
    #
    # Tests the provider configuration
    def test_provider
      unless @provider_config.ready?
        redirect_to admin_llm_provider_config_path(@provider_config), alert: "Provider is not ready. Please ensure it is enabled and has an API key configured."
        return
      end

      # TODO: Implement actual test with sample HTML
      # For now, just show a success message
      redirect_to admin_llm_provider_config_path(@provider_config), notice: "Provider test not yet implemented. Configuration looks valid."
    end

    private

    # Sets the provider config from params
    #
    # @return [void]
    def set_provider_config
      @provider_config = LlmProviderConfig.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_llm_provider_configs_path, alert: "LLM provider config not found."
    end

    # Returns filtered provider configs based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_provider_configs
      configs = LlmProviderConfig.all

      # Filter by enabled status
      if params[:enabled].present?
        case params[:enabled]
        when "true"
          configs = configs.where(enabled: true)
        when "false"
          configs = configs.where(enabled: false)
        end
      end

      # Filter by provider type
      if params[:provider_type].present?
        configs = configs.where(provider_type: params[:provider_type])
      end

      # Search by name
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        configs = configs.where("name ILIKE :q OR llm_model ILIKE :q", q: search_term)
      end

      # Sort
      case params[:sort]
      when "name"
        configs = configs.order(:name)
      when "priority"
        configs = configs.order(:priority, :created_at)
      when "provider_type"
        configs = configs.order(:provider_type, :priority)
      else
        configs = configs.order(:priority, :created_at)
      end

      configs
    end

    # Calculates overall stats
    #
    # @return [Hash]
    def calculate_stats
      base = LlmProviderConfig.all

      {
        total: base.count,
        enabled: base.where(enabled: true).count,
        disabled: base.where(enabled: false).count,
        ready: base.select(&:ready?).count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:search, :enabled, :provider_type, :sort, :page)
    end

    # Strong params for provider config
    #
    # @return [ActionController::Parameters] Permitted params
    def provider_config_params
      permitted = params.require(:llm_provider_config).permit(
        :name, :provider_type, :llm_model, :priority, :enabled,
        :max_tokens, :temperature, :api_endpoint, :settings
      )

      # Parse settings JSON if it's a string
      if permitted[:settings].is_a?(String)
        begin
          permitted[:settings] = JSON.parse(permitted[:settings])
        rescue JSON::ParserError
          # If invalid JSON, keep as string and let validation handle it
        end
      end

      permitted
    end
  end
end
