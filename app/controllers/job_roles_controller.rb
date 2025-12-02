# frozen_string_literal: true

# Controller for managing job roles
class JobRolesController < ApplicationController
  # GET /job_roles
  def index
    @job_roles = JobRole.alphabetical

    if params[:q].present?
      @job_roles = @job_roles.where("title ILIKE ?", "%#{params[:q]}%")
    end

    if params[:category].present?
      @job_roles = @job_roles.by_category(params[:category])
    end

    @job_roles = @job_roles.limit(50)

    respond_to do |format|
      format.html
      format.json { render json: @job_roles }
    end
  end

  # GET /job_roles/autocomplete
  def autocomplete
    query = params[:q].to_s.strip

    @job_roles = if query.present?
      JobRole.where("title ILIKE ?", "%#{query}%")
        .alphabetical
        .limit(10)
    else
      JobRole.alphabetical.limit(10)
    end

    render json: @job_roles.map { |jr| { id: jr.id, title: jr.title, category: jr.category } }
  end

  # POST /job_roles
  def create
    # Handle both form params and JSON params (for auto-create)
    if request.format.json?
      # Auto-create from autocomplete - only title is required
      title = (params[:title] || params.dig(:job_role, :title))&.strip
      return render json: { errors: [ "Title is required" ] }, status: :unprocessable_entity if title.blank?

      # Find by case-insensitive title
      @job_role = JobRole.where("LOWER(title) = ?", title.downcase).first

      if @job_role.nil?
        # Create new job role
        @job_role = JobRole.new(title: title)
        if @job_role.save
          render json: { id: @job_role.id, title: @job_role.title, name: @job_role.title }, status: :created
        else
          render json: { errors: @job_role.errors.full_messages }, status: :unprocessable_entity
        end
      else
        # Job role already exists, return it
        render json: { id: @job_role.id, title: @job_role.title, name: @job_role.title }, status: :ok
      end
    else
      # Regular form submission
      @job_role = JobRole.new(job_role_params)

      if @job_role.save
        respond_to do |format|
          format.html { redirect_to job_roles_path, notice: "Job role created successfully!" }
          format.turbo_stream { flash.now[:notice] = "Job role created successfully!" }
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end
  end

  private

  def job_role_params
    params.expect(job_role: [ :title, :category, :description ])
  end
end
