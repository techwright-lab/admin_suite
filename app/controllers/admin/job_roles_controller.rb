# frozen_string_literal: true

module Admin
  # Controller for managing job roles in the admin panel
  #
  # Provides full CRUD for job roles with associations visibility
  class JobRolesController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable
    include Concerns::StatsCalculator

    PER_PAGE = 30

    before_action :set_job_role, only: [ :show, :edit, :update, :destroy ]

    # GET /admin/job_roles
    #
    # Lists job roles with filtering and search
    def index
      @pagy, @job_roles = paginate(filtered_job_roles)
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/job_roles/:id
    #
    # Shows job role details with associations
    def show
      @job_listings = @job_role.job_listings.recent.limit(10)
      @interview_applications = @job_role.interview_applications.recent.limit(10)
      @current_users = @job_role.users_with_current_role.limit(10)
      @users_targeting = @job_role.users_targeting.limit(10)
    end

    # GET /admin/job_roles/new
    def new
      @job_role = JobRole.new
    end

    # POST /admin/job_roles
    def create
      @job_role = JobRole.new(job_role_params)

      if @job_role.save
        redirect_to admin_job_role_path(@job_role), notice: "Job role created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/job_roles/:id/edit
    def edit
    end

    # PATCH/PUT /admin/job_roles/:id
    def update
      if @job_role.update(job_role_params)
        redirect_to admin_job_role_path(@job_role), notice: "Job role updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/job_roles/:id
    def destroy
      @job_role.destroy
      redirect_to admin_job_roles_path, notice: "Job role deleted.", status: :see_other
    end

    private

    # Sets the job role from params
    #
    # @return [void]
    def set_job_role
      @job_role = JobRole.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_job_roles_path, alert: "Job role not found."
    end

    # Returns filtered job roles based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_job_roles
      job_roles = JobRole.all

      # Filter by category
      if params[:category].present?
        job_roles = job_roles.where(category: params[:category])
      end

      # Search by title or category
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        job_roles = job_roles.where("title ILIKE :q OR category ILIKE :q", q: search_term)
      end

      # Sort
      case params[:sort]
      when "title"
        job_roles = job_roles.order(:title)
      when "category"
        job_roles = job_roles.order(:category, :title)
      when "recent"
        job_roles = job_roles.order(created_at: :desc)
      else
        job_roles = job_roles.order(:title)
      end

      job_roles
    end

    # Calculates overall stats
    #
    # @return [Hash]
    def calculate_stats
      base = JobRole.all

      {
        total: base.count,
        with_category: base.where.not(category: [ nil, "" ]).count,
        with_description: base.where.not(description: [ nil, "" ]).count,
        with_job_listings: base.joins(:job_listings).distinct.count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:search, :category, :sort, :page)
    end

    # Strong params for job role
    #
    # @return [ActionController::Parameters] Permitted params
    def job_role_params
      params.require(:job_role).permit(:title, :category, :description)
    end
  end
end
