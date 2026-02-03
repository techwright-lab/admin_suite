# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: list interview applications for the current user.
    class ListInterviewApplicationsTool < BaseTool
      def call(args:, tool_execution:)
        status = normalize_filter_value(args["status"] || args[:status])
        stage = normalize_filter_value(args["pipeline_stage"] || args[:pipeline_stage])
        limit = (args["limit"] || args[:limit] || 20).to_i.clamp(1, 50)

        scope = user.interview_applications.includes(:company, :job_role).order(created_at: :desc)
        scope = scope.where(status: status) if status.present?
        scope = scope.where(pipeline_stage: stage) if stage.present?

        apps = scope.limit(limit)

        {
          success: true,
          data: {
            count: apps.size,
            applications: apps.map { |a|
              next_round = a.interview_rounds.upcoming.order(:scheduled_at).first
              {
                uuid: a.uuid,
                id: a.id,
                status: a.status,
                pipeline_stage: a.pipeline_stage,
                company: a.display_company&.name,
                job_role: a.display_job_role&.title,
                applied_at: a.applied_at,
                next_interview: next_round ? serialize_round(next_round) : nil
              }
            }
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      # Normalizes "all"/blank filter values to nil.
      #
      # LLMs commonly emit sentinel values like "all" even when the schema doesn't require it.
      # Treat these as "no filter" so the tool behaves intuitively.
      #
      # @param value [Object]
      # @return [String, nil]
      def normalize_filter_value(value)
        v = value.to_s.strip
        return nil if v.blank?
        return nil if v.casecmp("all").zero?
        return nil if v.casecmp("any").zero?

        v
      end

      def serialize_round(round)
        {
          id: round.id,
          stage: round.stage,
          stage_name: round.stage_display_name,
          scheduled_at: round.scheduled_at,
          interviewer: round.interviewer_display,
          duration_minutes: round.duration_minutes
        }
      end
    end
  end
end
