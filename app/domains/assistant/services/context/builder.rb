# frozen_string_literal: true

module Assistant
  module Context
    # Builds a bounded context snapshot for the assistant.
    #
    # This should remain deterministic and small; it is persisted for observability.
    #
    # Context Strategy:
    # - Always include: user summary, top skills, work history summary, target roles/domains
    # - Include resume summary: by default (low token cost)
    # - Include full resume text: only when page_context[:include_full_resume] is true
    #   (e.g., user is on resume page, or query explicitly needs raw resume content)
    class Builder
      # Maximum work experiences to include
      MAX_WORK_EXPERIENCES = 5
      # Maximum skills per work experience
      MAX_SKILLS_PER_EXPERIENCE = 5

      def initialize(user:, page_context: {})
        @user = user
        @page_context = page_context.to_h.symbolize_keys
      end

      def build
        {
          user: user_summary,
          career: career_summary,
          skills: skill_summary,
          pipeline: pipeline_summary,
          page: page_summary
        }
      end

      private

      attr_reader :user, :page_context

      def user_summary
        {
          id: user.id,
          name: user.display_name,
          email_verified: user.email_verified?,
          created_at: user.created_at&.iso8601
        }
      end

      # Career context: resume summaries, work history, targets
      # This provides rich context with minimal tokens (~300-800 tokens)
      def career_summary
        latest = latest_resume
        extraction = resume_extraction(latest)

        {
          resume: resume_summary(latest, extraction),
          work_history: work_history_summary,
          targets: targets_summary
        }.compact
      end

      def resume_summary(latest, extraction)
        return nil if latest.nil?

        summary = {
          profile_summary: latest.analysis_summary,
          strengths: Array(extraction["strengths"]).first(5),
          domains: Array(extraction["domains"]).first(5),
          resume_count: user.user_resumes.count,
          latest_analyzed_at: latest.analyzed_at&.iso8601
        }.compact

        # Include full resume text only when explicitly requested
        if include_full_resume?
          summary[:full_text] = latest.parsed_text.to_s.truncate(10_000)
        end

        summary
      end

      def work_history_summary
        experiences = user.user_work_experiences
                         .reverse_chronological
                         .includes(:skill_tags)
                         .limit(MAX_WORK_EXPERIENCES)

        return nil if experiences.empty?

        experiences.map do |exp|
          {
            title: exp.display_role_title,
            company: exp.display_company_name,
            current: exp.current,
            start_date: exp.start_date&.strftime("%b %Y"),
            end_date: exp.current ? "Present" : exp.end_date&.strftime("%b %Y"),
            highlights: Array(exp.highlights).first(3),
            skills: exp.skill_tags.pluck(:name).first(MAX_SKILLS_PER_EXPERIENCE)
          }.compact
        end
      end

      def targets_summary
        target_roles = user.respond_to?(:target_job_roles) ? user.target_job_roles.pluck(:title).first(5) : []
        target_companies = user.respond_to?(:target_companies) ? user.target_companies.pluck(:name).first(5) : []
        target_domains = user.respond_to?(:target_domains) ? user.target_domains.pluck(:name).first(5) : []

        targets = {
          roles: target_roles.presence,
          companies: target_companies.presence,
          domains: target_domains.presence
        }.compact

        targets.presence
      end

      def skill_summary
        top = user.respond_to?(:top_skills) ? user.top_skills(limit: 10) : []

        {
          top_skills: Array(top).map do |us|
            {
              name: us.try(:skill_tag)&.try(:name),
              level: us.try(:level),
              evidence: us.try(:evidence).presence
            }.compact
          end.compact
        }
      end

      def pipeline_summary
        apps = user.interview_applications.order(updated_at: :desc).limit(10)
        {
          interview_applications_count: user.interview_applications.count,
          recent_interview_applications: apps.map do |a|
            {
              uuid: a.uuid,
              id: a.id,
              company: a.company&.name,
              job_role: a.job_role&.title,
              status: a.status,
              updated_at: a.updated_at&.iso8601
            }.compact
          end
        }
      end

      def page_summary
        summary = {
          job_listing_id: page_context[:job_listing_id],
          interview_application_id: page_context[:interview_application_id],
          interview_application_uuid: page_context[:interview_application_uuid],
          opportunity_id: page_context[:opportunity_id],
          resume_id: page_context[:resume_id]
        }.compact

        focused = focused_interview_application_summary
        summary[:focused_interview_application] = focused if focused.present?

        summary
      end

      # Helper methods

      def latest_resume
        @latest_resume ||= user.user_resumes
                               .analyzed
                               .recent_first
                               .first
      end

      def resume_extraction(resume)
        return {} if resume.nil?

        data = resume.extracted_data
        data = JSON.parse(data) if data.is_a?(String)
        data&.dig("resume_extraction", "parsed") || {}
      rescue JSON::ParserError
        {}
      end

      # Include full resume text when:
      # 1. Explicitly requested via page_context
      # 2. User is viewing a resume page (resume_id present)
      def include_full_resume?
        page_context[:include_full_resume] == true ||
          page_context[:resume_id].present?
      end

      # @return [InterviewApplication, nil]
      def focused_interview_application
        uuid = page_context[:interview_application_uuid].to_s.presence
        id = page_context[:interview_application_id]

        if uuid.present?
          return user.interview_applications.includes(:company, :job_role, :interview_rounds).find_by(uuid: uuid)
        end

        if id.present?
          return user.interview_applications.includes(:company, :job_role, :interview_rounds).find_by(id: id)
        end

        nil
      end

      # @return [Hash, nil]
      def focused_interview_application_summary
        app = focused_interview_application
        return nil if app.nil?

        next_round = app.interview_rounds.upcoming.order(:scheduled_at).first
        {
          uuid: app.uuid,
          id: app.id,
          company: app.display_company&.name,
          job_role: app.display_job_role&.title,
          status: app.status,
          pipeline_stage: app.pipeline_stage,
          applied_at: app.applied_at&.iso8601,
          notes_preview: app.notes.to_s.truncate(500),
          next_interview: next_round ? {
            id: next_round.id,
            stage: next_round.stage,
            stage_name: next_round.stage_display_name,
            scheduled_at: next_round.scheduled_at,
            interviewer: next_round.interviewer_display
          }.compact : nil,
          needs_scheduling: app.needs_scheduling?,
          actionable_scheduling_link: app.actionable_scheduling_link
        }.compact
      rescue StandardError
        nil
      end
    end
  end
end
