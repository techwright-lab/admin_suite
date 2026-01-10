# frozen_string_literal: true

# API controller for departments (job role categories)
class Api::V1::DepartmentsController < Api::V1::BaseController
  # GET /api/v1/departments
  # List all departments with their job role counts
  def index
    @departments = Category.departments

    render json: {
      departments: @departments.map { |dept| department_json(dept) }
    }
  end

  private

  # Serializes department for JSON response
  # @param dept [Category]
  # @return [Hash]
  def department_json(dept)
    {
      id: dept.id,
      name: dept.name,
      job_role_count: dept.job_roles.enabled.count
    }
  end
end
