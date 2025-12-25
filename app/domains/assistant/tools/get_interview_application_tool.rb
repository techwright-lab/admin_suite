# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: fetch a single interview application for the current user.
    class GetInterviewApplicationTool < BaseTool
      def call(args:, tool_execution:)
        uuid = (args["application_uuid"] || args[:application_uuid]).to_s
        return { success: false, error: "application_uuid is required" } if uuid.blank?

        app = user.interview_applications.includes(:company, :job_role, interview_rounds: :interview_feedback).find_by(uuid: uuid)
        return { success: false, error: "Interview application not found" } if app.nil?

        rounds = app.interview_rounds.ordered.map { |r|
          {
            id: r.id,
            stage: r.stage,
            stage_name: r.stage_display_name,
            scheduled_at: r.scheduled_at,
            completed_at: r.completed_at,
            result: r.result,
            interviewer: r.interviewer_display,
            duration_minutes: r.duration_minutes,
            has_feedback: r.interview_feedback.present?
          }
        }

        {
          success: true,
          data: {
            application: {
              uuid: app.uuid,
              id: app.id,
              status: app.status,
              pipeline_stage: app.pipeline_stage,
              applied_at: app.applied_at,
              company: app.display_company&.name,
              job_role: app.display_job_role&.title,
              notes: app.notes
            },
            interview_rounds: rounds
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
