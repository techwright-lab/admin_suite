# frozen_string_literal: true

module Admin
  # Controller for viewing interview applications in the admin panel
  #
  # Provides read-only access to all interview applications for support/debugging
  class InterviewApplicationsController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable
    include Concerns::StatsCalculator

    PER_PAGE = 25

    before_action :set_interview_application, only: [ :show ]

    # GET /admin/interview_applications
    #
    # Lists all interview applications with filtering
    def index
      @pagy, @interview_applications = paginate(filtered_applications)
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/interview_applications/:id
    #
    # Shows interview application details
    def show
      @interview_rounds = @interview_application.interview_rounds.ordered
      @skill_tags = @interview_application.skill_tags
      @company_feedback = @interview_application.company_feedback
      @synced_emails = @interview_application.synced_emails.recent.limit(5)
    end

    private

    # Sets the interview application from params
    #
    # @return [void]
    def set_interview_application
      @interview_application = InterviewApplication.includes(
        :user, :company, :job_role, :job_listing,
        :interview_rounds, :skill_tags, :company_feedback
      ).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_interview_applications_path, alert: "Interview application not found."
    end

    # Returns filtered applications based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_applications
      applications = InterviewApplication.includes(:user, :company, :job_role)

      # Filter by status
      if params[:status].present?
        applications = applications.where(status: params[:status])
      end

      # Filter by pipeline_stage
      if params[:pipeline_stage].present?
        applications = applications.where(pipeline_stage: params[:pipeline_stage])
      end

      # Filter by user
      if params[:user_id].present?
        applications = applications.where(user_id: params[:user_id])
      end

      # Filter by company
      if params[:company_id].present?
        applications = applications.where(company_id: params[:company_id])
      end

      # Filter by job_role
      if params[:job_role_id].present?
        applications = applications.where(job_role_id: params[:job_role_id])
      end

      # Search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        applications = applications.joins(:user, :company, :job_role).where(
          "users.name ILIKE :q OR users.email_address ILIKE :q OR companies.name ILIKE :q OR job_roles.title ILIKE :q",
          q: search_term
        )
      end

      # Sort
      case params[:sort]
      when "recent"
        applications = applications.order(created_at: :desc)
      when "applied_at"
        applications = applications.order(applied_at: :desc)
      when "user"
        applications = applications.joins(:user).order("users.name")
      else
        applications = applications.order(created_at: :desc)
      end

      applications
    end

    # Calculates overall stats
    #
    # @return [Hash]
    def calculate_stats
      base = InterviewApplication.all

      {
        total: base.count,
        by_status: base.group(:status).count,
        by_pipeline_stage: base.group(:pipeline_stage).count,
        with_rounds: base.joins(:interview_rounds).distinct.count,
        with_feedback: base.joins(:company_feedback).distinct.count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:search, :status, :pipeline_stage, :user_id, :company_id, :job_role_id, :sort, :page)
    end
  end
end
