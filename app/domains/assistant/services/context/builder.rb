# frozen_string_literal: true

module Assistant
  module Context
    # Builds a bounded context snapshot for the assistant.
    #
    # This should remain deterministic and small; it is persisted for observability.
    class Builder
      def initialize(user:, page_context: {})
        @user = user
        @page_context = page_context.to_h.symbolize_keys
      end

      def build
        {
          user: user_summary,
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
        {
          job_listing_id: page_context[:job_listing_id],
          interview_application_id: page_context[:interview_application_id],
          opportunity_id: page_context[:opportunity_id]
        }.compact
      end
    end
  end
end
