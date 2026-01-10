# frozen_string_literal: true

# API controller for job roles search and creation
class Api::V1::JobRolesController < Api::V1::BaseController
  # GET /api/v1/job_roles
  # Search job roles with optional department filter
  def index
    @job_roles = JobRole.enabled.alphabetical

    if params[:q].present?
      @job_roles = @job_roles.search(params[:q])
    end

    if params[:department_id].present?
      @job_roles = @job_roles.by_department(params[:department_id])
    end

    @job_roles = @job_roles.includes(:category).limit(params[:limit] || 50)

    render json: {
      job_roles: @job_roles.map { |role| job_role_json(role) },
      total: @job_roles.size
    }
  end

  # POST /api/v1/job_roles
  # Creates a new job role (user-created)
  def create
    @job_role = JobRole.new(job_role_params)

    # Assign to department if provided
    if params[:department_id].present?
      @job_role.category = Category.find_by(id: params[:department_id], kind: :job_role)
    end

    if @job_role.save
      render json: { success: true, job_role: job_role_json(@job_role) }, status: :created
    else
      render json: { success: false, errors: @job_role.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Strong parameters for job role creation
  # @return [ActionController::Parameters]
  def job_role_params
    params.require(:job_role).permit(:title, :description)
  end

  # Serializes job role for JSON response
  # @param role [JobRole]
  # @return [Hash]
  def job_role_json(role)
    {
      id: role.id,
      title: role.title,
      description: role.description,
      department_id: role.category_id,
      department_name: role.department_name
    }
  end
end
