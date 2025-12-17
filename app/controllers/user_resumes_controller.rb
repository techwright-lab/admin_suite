# frozen_string_literal: true

# Controller for managing user resumes and skill profiles
#
# Provides CRUD operations for resumes and displays the aggregated skill profile
class UserResumesController < ApplicationController
  before_action :set_user_resume, only: [ :show, :edit, :update, :destroy, :reanalyze ]

  # GET /resumes
  #
  # Main resumes view with CV list and aggregated skill profile
  def index
    @user_resumes = current_user_resumes.recent_first.includes(:target_job_roles, :target_companies)
    @user_skills = Current.user.user_skills.includes(:skill_tag).by_level_desc
    @skills_by_category = @user_skills.group_by(&:category)
    @job_roles = JobRole.order(:title)
    @companies = Company.order(:name)

    @merged_strengths = merged_strengths_for(Current.user)
    @resume_domains = aggregated_label_counts(Current.user.user_resumes.analyzed.pluck(:domains).flatten)
  end

  # GET /resumes/:id
  #
  # Show resume details with extracted skills for review
  def show
    base_skills = @user_resume.resume_skills
      .includes(:skill_tag)
      .order(Arel.sql("COALESCE(user_level, model_level) DESC"))

    @pagy, @resume_skills = pagy(base_skills, limit: 25)
    @skills_by_category = @resume_skills.group_by(&:category)
    @total_skills_count = base_skills.count

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json do
        render json: {
          id: @user_resume.id,
          analysis_status: @user_resume.analysis_status,
          skills_count: @total_skills_count
        }
      end
    end
  end

  # GET /resumes/new
  #
  # Upload form for new resume
  def new
    @user_resume = Current.user.user_resumes.build
    @job_roles = JobRole.order(:title)
    @companies = Company.order(:name)
  end

  # POST /resumes
  #
  # Create a new resume and enqueue analysis
  def create
    @user_resume = Current.user.user_resumes.build(user_resume_params)

    if @user_resume.save
      # Always redirect to show page to see processing status
      redirect_to user_resume_path(@user_resume), notice: "Resume uploaded! Analysis in progress..."
    else
      @job_roles = JobRole.order(:title)
      @companies = Company.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  # GET /resumes/:id/edit
  #
  # Edit resume metadata (name, purpose, target role/company)
  def edit
    @job_roles = JobRole.order(:title)
    @companies = Company.order(:name)
  end

  # PATCH/PUT /resumes/:id
  #
  # Update resume metadata
  def update
    respond_to do |format|
      if @user_resume.update(user_resume_params)
        format.html { redirect_to user_resume_path(@user_resume), notice: "Resume updated." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("resume_card_#{@user_resume.id}", partial: "user_resumes/resume_card", locals: { user_resume: @user_resume }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { flash: { notice: "Resume updated." } })
          ]
        end
      else
        format.html do
          @job_roles = JobRole.order(:title)
          @companies = Company.order(:name)
          render :edit, status: :unprocessable_entity
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "flash",
            partial: "shared/flash",
            locals: { flash: { alert: @user_resume.errors.full_messages.join(", ") } }
          )
        end
      end
    end
  end

  # DELETE /resumes/:id
  #
  # Delete resume and trigger skill re-aggregation
  def destroy
    @user_resume.destroy!

    # Re-aggregate skills for the user
    Resumes::SkillAggregationService.new(Current.user).aggregate_all

    respond_to do |format|
      format.html { redirect_to user_resumes_path, notice: "Resume deleted." }
      format.turbo_stream do
        @user_skills = Current.user.user_skills.includes(:skill_tag).by_level_desc
        @merged_strengths = merged_strengths_for(Current.user)
        @resume_domains = aggregated_label_counts(Current.user.user_resumes.analyzed.pluck(:domains).flatten)
        render turbo_stream: [
          turbo_stream.remove("resume_card_#{params[:id]}"),
          turbo_stream.update("skill_profile", partial: "user_resumes/skill_profile", locals: { user_skills: @user_skills, merged_strengths: @merged_strengths, domains: @resume_domains }),
          turbo_stream.update("flash", partial: "shared/flash", locals: { flash: { notice: "Resume deleted." } })
        ]
      end
    end
  end

  # POST /resumes/:id/reanalyze
  #
  # Re-run AI analysis on existing resume
  def reanalyze
    if @user_resume.analysis_status_processing?
      respond_to do |format|
        format.html { redirect_to user_resume_path(@user_resume), alert: "Analysis already in progress." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "flash",
            partial: "shared/flash",
            locals: { flash: { alert: "Analysis already in progress." } }
          )
        end
      end
      return
    end

    # Reset status and re-enqueue
    @user_resume.update!(analysis_status: :pending)
    AnalyzeResumeJob.perform_later(@user_resume)

    respond_to do |format|
      format.html { redirect_to user_resume_path(@user_resume), notice: "Re-analysis started..." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("resume_status_#{@user_resume.id}", partial: "user_resumes/analysis_status", locals: { user_resume: @user_resume }),
          turbo_stream.update("flash", partial: "shared/flash", locals: { flash: { notice: "Re-analysis started..." } })
        ]
      end
    end
  end

  private

  # Sets the resume for member actions
  #
  # @return [UserResume]
  def set_user_resume
    @user_resume = current_user_resumes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to user_resumes_path, alert: "Resume not found." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "flash",
          partial: "shared/flash",
          locals: { flash: { alert: "Resume not found." } }
        )
      end
    end
  end

  # Returns the current user's resumes
  #
  # @return [ActiveRecord::Relation]
  def current_user_resumes
    Current.user.user_resumes
  end

  # Strong parameters for resume creation/update
  #
  # @return [ActionController::Parameters]
  def user_resume_params
    params.require(:user_resume).permit(
      :name,
      :file,
      :purpose,
      target_job_role_ids: [],
      target_company_ids: []
    )
  end

  # Aggregates a list of labels into a normalized hash with counts.
  #
  # @param labels [Array<String>]
  # @return [Hash{String => Hash}] e.g. { "system design" => { label: "System Design", count: 2 } }
  def aggregated_label_counts(labels)
    labels = Array(labels).map { |l| l.to_s.strip }.reject(&:blank?)
    counts = {}

    labels.each do |label|
      key = normalize_label_key(label)
      next if key.blank?

      counts[key] ||= { label: label, count: 0 }
      counts[key][:count] += 1
    end

    counts
  end

  def merged_strengths_for(user)
    resume_counts = aggregated_label_counts(user.user_resumes.analyzed.pluck(:strengths).flatten)

    feedback_strengths = ProfileInsightsService.new(user).generate_insights[:strengths] || []
    feedback_counts = {}
    feedback_strengths.each do |row|
      name = row[:name] || row["name"]
      count = row[:count] || row["count"] || 0
      key = normalize_label_key(name)
      next if key.blank?

      feedback_counts[key] ||= { label: name.to_s.strip, count: 0 }
      feedback_counts[key][:count] += count.to_i
    end

    keys = (resume_counts.keys + feedback_counts.keys).uniq
    merged = keys.map do |key|
      resume = resume_counts[key]
      feedback = feedback_counts[key]

      label = resume&.dig(:label).presence || feedback&.dig(:label).presence || key
      resume_count = resume&.dig(:count).to_i
      feedback_count = feedback&.dig(:count).to_i
      sources = []
      sources << "resume" if resume_count.positive?
      sources << "feedback" if feedback_count.positive?

      {
        key: key,
        label: label,
        total_count: resume_count + feedback_count,
        resume_count: resume_count,
        feedback_count: feedback_count,
        sources: sources
      }
    end

    merged.sort_by { |h| -h[:total_count].to_i }
  end

  def normalize_label_key(label)
    label.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
