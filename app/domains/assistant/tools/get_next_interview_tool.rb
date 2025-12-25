# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: return the user's next upcoming interview round (across all applications).
    class GetNextInterviewTool < BaseTool
      def call(args:, tool_execution:)
        round = user.interview_rounds
          .includes(:interview_application)
          .upcoming
          .order(:scheduled_at)
          .first

        return { success: true, data: { next_interview: nil } } if round.nil?

        app = round.interview_application

        {
          success: true,
          data: {
            next_interview: {
              interview_round: {
                id: round.id,
                stage: round.stage,
                stage_name: round.stage_display_name,
                scheduled_at: round.scheduled_at,
                interviewer: round.interviewer_display,
                duration_minutes: round.duration_minutes
              },
              interview_application: {
                uuid: app.uuid,
                id: app.id,
                company: app.display_company&.name,
                job_role: app.display_job_role&.title
              }
            }
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
