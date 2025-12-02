# frozen_string_literal: true

# Controller for user profile and insights
class ProfilesController < ApplicationController
  # GET /profile
  def show
    @user = Current.user
    @insights = ProfileInsightsService.new(@user).generate_insights
    @companies = Company.alphabetical.limit(100)
    @job_roles = JobRole.alphabetical.limit(100)
  end

  # GET /profile/edit
  def edit
    @user = Current.user
    @companies = Company.alphabetical.limit(100)
    @job_roles = JobRole.alphabetical.limit(100)
  end

  # PATCH/PUT /profile
  def update
    @user = Current.user

    if @user.update(profile_params)
      redirect_to profile_path, notice: "Profile updated successfully!"
    else
      @companies = Company.alphabetical.limit(100)
      @job_roles = JobRole.alphabetical.limit(100)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.expect(user: [
      :name,
      :bio,
      :current_job_role_id,
      :current_company_id,
      :years_of_experience,
      :linkedin_url,
      :github_url,
      :gitlab_url,
      :twitter_url,
      :portfolio_url,
      target_job_role_ids: [],
      target_company_ids: []
    ])
  end
end

