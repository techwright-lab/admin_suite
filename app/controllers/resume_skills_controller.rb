# frozen_string_literal: true

# Controller for managing individual skills extracted from resumes
#
# Handles user adjustments to skill levels and skill management (delete, merge)
class ResumeSkillsController < ApplicationController
  before_action :set_user_resume
  before_action :set_resume_skill, only: [ :update, :destroy ]

  # PATCH /resumes/:user_resume_id/skills/:id
  #
  # Update user-confirmed proficiency level for a skill
  def update
    respond_to do |format|
      if @resume_skill.update(resume_skill_params)
        format.html { redirect_to user_resume_path(@user_resume), notice: "Skill updated." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "skill_row_#{@resume_skill.id}",
            partial: "resume_skills/skill_row",
            locals: { resume_skill: @resume_skill }
          )
        end
        format.json { render json: { success: true, skill: skill_json(@resume_skill) } }
      else
        format.html { redirect_to user_resume_path(@user_resume), alert: "Could not update skill." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "flash",
            partial: "shared/flash",
            locals: { flash: { alert: @resume_skill.errors.full_messages.join(", ") } }
          )
        end
        format.json { render json: { success: false, errors: @resume_skill.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /resumes/:user_resume_id/skills/:id
  #
  # Remove an irrelevant skill from the resume
  def destroy
    skill_name = @resume_skill.skill_name
    @resume_skill.destroy!

    respond_to do |format|
      format.html { redirect_to user_resume_path(@user_resume), notice: "#{skill_name} removed." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("skill_row_#{params[:id]}"),
          turbo_stream.update("flash", partial: "shared/flash", locals: { flash: { notice: "#{skill_name} removed." } })
        ]
      end
      format.json { render json: { success: true } }
    end
  end

  # POST /resumes/:user_resume_id/skills/merge
  #
  # Merge duplicate skills (e.g., "PostgreSQL" and "Postgres")
  def merge
    source_skill_id = params[:source_skill_id]
    target_skill_id = params[:target_skill_id]

    source_skill = SkillTag.find_by(id: source_skill_id)
    target_skill = SkillTag.find_by(id: target_skill_id)

    unless source_skill && target_skill
      respond_to do |format|
        format.html { redirect_to user_resume_path(@user_resume), alert: "Skills not found." }
        format.json { render json: { success: false, error: "Skills not found" }, status: :not_found }
      end
      return
    end

    if SkillTag.merge_skills(source_skill, target_skill)
      # Re-aggregate skills for the user
      Resumes::SkillAggregationService.new(Current.user).aggregate_skill(target_skill)

      respond_to do |format|
        format.html { redirect_to user_resume_path(@user_resume), notice: "Skills merged successfully." }
        format.turbo_stream do
          @resume_skills = @user_resume.resume_skills.includes(:skill_tag).order(Arel.sql("COALESCE(user_level, model_level) DESC"))
          render turbo_stream: [
            turbo_stream.update("skills_list", partial: "resume_skills/skills_list", locals: { resume_skills: @resume_skills }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { flash: { notice: "Skills merged successfully." } })
          ]
        end
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to user_resume_path(@user_resume), alert: "Could not merge skills." }
        format.json { render json: { success: false, error: "Merge failed" }, status: :unprocessable_entity }
      end
    end
  end

  # POST /resumes/:user_resume_id/skills/bulk_update
  #
  # Update multiple skills at once (after review)
  def bulk_update
    skills_data = params[:skills] || []
    updated_count = 0

    skills_data.each do |skill_data|
      resume_skill = @user_resume.resume_skills.find_by(id: skill_data[:id])
      next unless resume_skill

      if resume_skill.update(user_level: skill_data[:user_level])
        updated_count += 1
      end
    end

    respond_to do |format|
      format.html { redirect_to user_resume_path(@user_resume), notice: "#{updated_count} skills updated." }
      format.turbo_stream do
        @resume_skills = @user_resume.resume_skills.includes(:skill_tag).order(Arel.sql("COALESCE(user_level, model_level) DESC"))
        render turbo_stream: [
          turbo_stream.update("skills_list", partial: "resume_skills/skills_list", locals: { resume_skills: @resume_skills }),
          turbo_stream.update("flash", partial: "shared/flash", locals: { flash: { notice: "#{updated_count} skills updated." } })
        ]
      end
      format.json { render json: { success: true, updated_count: updated_count } }
    end
  end

  private

  # Sets the parent resume
  #
  # @return [UserResume]
  def set_user_resume
    @user_resume = Current.user.user_resumes.find(params[:user_resume_id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to user_resumes_path, alert: "Resume not found." }
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end

  # Sets the resume skill for member actions
  #
  # @return [ResumeSkill]
  def set_resume_skill
    @resume_skill = @user_resume.resume_skills.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to user_resume_path(@user_resume), alert: "Skill not found." }
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end

  # Strong parameters for skill updates
  #
  # @return [ActionController::Parameters]
  def resume_skill_params
    params.expect(resume_skill: [ :user_level ])
  end

  # Builds JSON representation of a skill
  #
  # @param resume_skill [ResumeSkill]
  # @return [Hash]
  def skill_json(resume_skill)
    {
      id: resume_skill.id,
      skill_name: resume_skill.skill_name,
      model_level: resume_skill.model_level,
      user_level: resume_skill.user_level,
      effective_level: resume_skill.effective_level,
      confidence_score: resume_skill.confidence_score,
      category: resume_skill.category
    }
  end
end
