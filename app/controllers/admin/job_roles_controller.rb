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

    before_action :set_job_role, only: [ :show, :edit, :update, :destroy, :disable, :enable, :merge, :merge_into ]

    # GET /admin/job_roles
    #
    # Lists job roles with filtering and search
    def index
      @pagy, @job_roles = paginate(filtered_job_roles)
      @stats = calculate_stats
      @filters = filter_params

      @selected_category = Category.find_by(id: params[:category_id]) if params[:category_id].present?
    end

    # GET /admin/job_roles/:id
    #
    # Shows job role details with associations
    def show
      @job_listings = @job_role.job_listings.recent.limit(10)
      @interview_applications = @job_role.interview_applications.recent.limit(10)
      @current_users = @job_role.users_with_current_role.limit(10)
      @users_targeting = @job_role.users_targeting.limit(10)
      @duplicate_suggestions = Dedup::FindJobRoleDuplicatesService.new(job_role: @job_role).run
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

    # POST /admin/job_roles/:id/disable
    def disable
      @job_role.disable! unless @job_role.disabled?
      redirect_back fallback_location: admin_job_role_path(@job_role), notice: "Job role disabled."
    end

    # POST /admin/job_roles/:id/enable
    def enable
      @job_role.enable! if @job_role.disabled?
      redirect_back fallback_location: admin_job_role_path(@job_role), notice: "Job role enabled."
    end

    # GET /admin/job_roles/:id/merge
    def merge
      @selected_target_job_role = JobRole.find_by(id: params[:target_job_role_id]) if params[:target_job_role_id].present?
    end

    # POST /admin/job_roles/:id/merge_into
    def merge_into
      target = JobRole.find(params[:target_job_role_id])

      Dedup::MergeJobRoleService.new(source_job_role: @job_role, target_job_role: target).run

      redirect_to admin_job_role_path(target), notice: "Job role merged into #{target.title}."
    rescue ActiveRecord::RecordNotFound
      redirect_back fallback_location: merge_admin_job_role_path(@job_role), alert: "Target job role not found."
    rescue ArgumentError => e
      redirect_back fallback_location: merge_admin_job_role_path(@job_role), alert: e.message
    end

    # DELETE /admin/job_roles/:id
    def destroy
      if @job_role.job_listings.exists?
        redirect_back(
          fallback_location: admin_job_role_path(@job_role),
          alert: "Can't delete a job role with job listings. Disable it instead (or merge duplicates)."
        )
        return
      end

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
      if params[:category_id].present?
        job_roles = job_roles.where(category_id: params[:category_id])
      end

      # Search by title or category
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        job_roles = job_roles.left_joins(:category).where("job_roles.title ILIKE :q OR categories.name ILIKE :q", q: search_term)
      end

      # Sort
      case params[:sort]
      when "title"
        job_roles = job_roles.order(:title)
      when "category"
        job_roles = job_roles.left_joins(:category).order(Arel.sql("categories.name NULLS LAST"), :title)
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
        with_category: base.where.not(category_id: nil).count,
        with_description: base.where.not(description: [ nil, "" ]).count,
        with_job_listings: base.joins(:job_listings).distinct.count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:search, :category_id, :sort, :page)
    end

    # Strong params for job role
    #
    # @return [ActionController::Parameters] Permitted params
    def job_role_params
      params.require(:job_role).permit(:title, :category_id, :description)
    end
  end
end
