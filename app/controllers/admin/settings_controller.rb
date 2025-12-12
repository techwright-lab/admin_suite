# frozen_string_literal: true

module Admin
  # Controller for managing settings in the admin panel
  #
  # Provides listing and editing for application settings
  class SettingsController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable

    PER_PAGE = 50

    before_action :set_setting, only: [ :show, :edit, :update ]

    # GET /admin/settings
    #
    # Lists all settings
    def index
      @pagy, @settings = paginate(filtered_settings)
      @filters = filter_params
      @available_settings = Setting::AVAILABLE_SETTINGS
    end

    # GET /admin/settings/new
    def new
      @setting = Setting.new
      @available_settings = Setting::AVAILABLE_SETTINGS
      @existing_setting_names = Setting.pluck(:name)
    end

    # POST /admin/settings
    def create
      @setting = Setting.new(setting_params)
      @available_settings = Setting::AVAILABLE_SETTINGS

      if @setting.save
        redirect_to admin_setting_path(@setting), notice: "Setting created successfully."
      else
        @existing_setting_names = Setting.pluck(:name)
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/settings/:id
    #
    # Shows setting details
    def show
    end

    # GET /admin/settings/:id/edit
    def edit
    end

    # PATCH/PUT /admin/settings/:id
    def update
      if @setting.update(setting_params)
        redirect_to admin_setting_path(@setting), notice: "Setting updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    # Sets the setting from params
    #
    # @return [void]
    def set_setting
      @setting = Setting.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_settings_path, alert: "Setting not found."
    end

    # Returns filtered settings based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_settings
      settings = Setting.all

      # Search by name
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        settings = settings.where("name ILIKE :q OR description ILIKE :q", q: search_term)
      end

      # Filter by value
      if params[:value].present?
        case params[:value]
        when "enabled"
          settings = settings.where(value: true)
        when "disabled"
          settings = settings.where(value: false)
        end
      end

      # Sort
      case params[:sort]
      when "name"
        settings = settings.order(:name)
      when "recent"
        settings = settings.order(updated_at: :desc)
      else
        settings = settings.order(:name)
      end

      settings
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:search, :value, :sort, :page)
    end

    # Strong params for setting
    #
    # @return [ActionController::Parameters] Permitted params
    def setting_params
      params.require(:setting).permit(:name, :value, :description)
    end
  end
end
