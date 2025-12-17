# frozen_string_literal: true

require "digest"

# Service for computing and persisting a FitAssessment for a user and a fittable.
#
# The fittable is expected to be owned by the user (same `user_id`).
#
# Scoring approach (v1):
# - Extract job skill mentions by scanning job text for `SkillTag` names (case-insensitive).
# - Weight matches by the user's `UserSkill.aggregated_level`.
# - Normalize to a 0..100 integer score.
#
# @example
#   ComputeFitAssessmentService.new(user: user, fittable: opportunity).call
#
class ComputeFitAssessmentService
  ALGORITHM_VERSION = "v1_keyword_skilltag_scan"

  # @param user [User]
  # @param fittable [Opportunity, SavedJob, InterviewApplication]
  def initialize(user:, fittable:)
    @user = user
    @fittable = fittable
  end

  # Computes and upserts a FitAssessment.
  #
  # @return [Hash] Result hash
  def call
    return error_result("User is required") unless @user
    return error_result("Fittable is required") unless @fittable
    return error_result("Fittable must belong to user") if @fittable.respond_to?(:user_id) && @fittable.user_id != @user.id

    job_text = build_job_text(@fittable)
    return upsert_failed("No job text available") if job_text.blank?

    matched = extract_job_skills(job_text)
    return upsert_failed("No skills found in job text") if matched.empty?

    user_skill_levels = @user.user_skills.pluck(:skill_tag_id, :aggregated_level).to_h

    matched_ids = matched.map { |m| m[:id] }
    matched_levels = matched_ids.map { |id| user_skill_levels[id].to_f }
    max_total = matched_ids.size * 5.0

    score = if max_total > 0
      ((matched_levels.sum / max_total) * 100).round.clamp(0, 100)
    end

    breakdown = build_breakdown(matched, user_skill_levels)
    inputs_digest = compute_inputs_digest(job_text, user_skill_levels)

    assessment = @fittable.fit_assessment
    if assessment&.inputs_digest == inputs_digest && assessment.computed?
      return { success: true, fit_assessment: assessment, skipped: true }
    end

    assessment ||= @fittable.build_fit_assessment(user: @user)
    assessment.assign_attributes(
      score: score,
      status: :computed,
      computed_at: Time.current,
      algorithm_version: ALGORITHM_VERSION,
      inputs_digest: inputs_digest,
      breakdown: breakdown
    )
    assessment.save!

    { success: true, fit_assessment: assessment }
  rescue ActiveRecord::RecordInvalid => e
    error_result(e.message)
  rescue StandardError => e
    Rails.logger.error("ComputeFitAssessmentService failed: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    error_result(e.message)
  end

  private

  def upsert_failed(message)
    assessment = @fittable.fit_assessment || @fittable.build_fit_assessment(user: @user)
    assessment.assign_attributes(
      score: nil,
      status: :failed,
      computed_at: Time.current,
      algorithm_version: ALGORITHM_VERSION,
      inputs_digest: compute_inputs_digest("", {}),
      breakdown: { error: message }
    )
    assessment.save!
    error_result(message, fit_assessment: assessment)
  end

  def error_result(message, fit_assessment: nil)
    { success: false, error: message, fit_assessment: fit_assessment }
  end

  def build_job_text(fittable)
    case fittable
    when InterviewApplication
      jl = fittable.job_listing
      parts = []
      parts << fittable.display_job_role&.title
      parts << fittable.display_company&.name
      if jl
        parts << jl.title
        parts << jl.description
        parts << jl.requirements
        parts << jl.responsibilities
        parts << jl.custom_sections&.values&.join("\n")
      end
      parts.compact.join("\n")
    when Opportunity
      [
        fittable.job_role_title,
        fittable.company_name,
        fittable.key_details,
        fittable.email_snippet,
        fittable.job_url
      ].compact.join("\n")
    when SavedJob
      if fittable.opportunity
        build_job_text(fittable.opportunity)
      else
        [
          fittable.title,
          fittable.job_role_title,
          fittable.company_name,
          fittable.notes,
          fittable.url
        ].compact.join("\n")
      end
    else
      nil
    end
  end

  def extract_job_skills(job_text)
    text = job_text.to_s.downcase
    tags = SkillTag.pluck(:id, :name)
    tags.filter_map do |(id, name)|
      next if name.blank?
      next unless text.include?(name.downcase)

      { id: id, name: name }
    end
  end

  def build_breakdown(matched, user_skill_levels)
    matched_ids = matched.map { |m| m[:id] }
    matched_names = matched.map { |m| m[:name] }

    missing_ids = matched_ids.reject { |id| user_skill_levels.key?(id) }
    missing_names = matched.select { |m| missing_ids.include?(m[:id]) }.map { |m| m[:name] }

    {
      method: "skilltag_scan",
      matched_skills: matched_names.uniq.sort,
      missing_skills: missing_names.uniq.sort,
      counts: {
        matched_in_job: matched_names.uniq.size,
        matched_in_user: (matched_ids & user_skill_levels.keys).uniq.size,
        missing_in_user: missing_ids.uniq.size
      }
    }
  end

  def compute_inputs_digest(job_text, user_skill_levels)
    skills_part = user_skill_levels
      .sort_by { |k, _| k }
      .map { |k, v| "#{k}:#{v.round(2)}" }
      .join("|")

    Digest::SHA256.hexdigest([ ALGORITHM_VERSION, job_text.to_s, skills_part ].join("\n"))
  end
end

