# frozen_string_literal: true

module Assistant
  module Tools
    # Write: create/schedule an interview round on an application.
    #
    # Supports both future scheduling and retroactive entry:
    # - scheduled_at: when it is/was scheduled
    # - completed_at: when it happened (optional)
    class CreateInterviewRoundTool < BaseTool
      def call(args:, tool_execution:)
        application_uuid = (args["application_uuid"] || args[:application_uuid]).to_s
        return { success: false, error: "application_uuid is required" } if application_uuid.blank?

        app = user.interview_applications.find_by(uuid: application_uuid)
        return { success: false, error: "Interview application not found" } if app.nil?

        stage = (args["stage"] || args[:stage] || "screening").to_s
        result = (args["result"] || args[:result] || "pending").to_s

        round = app.interview_rounds.build(
          stage: stage,
          result: result,
          stage_name: (args["stage_name"] || args[:stage_name]),
          interviewer_name: (args["interviewer_name"] || args[:interviewer_name]),
          interviewer_role: (args["interviewer_role"] || args[:interviewer_role]),
          duration_minutes: (args["duration_minutes"] || args[:duration_minutes]),
          scheduled_at: parse_time(args["scheduled_at"] || args[:scheduled_at]),
          completed_at: parse_time(args["completed_at"] || args[:completed_at]),
          notes: (args["notes"] || args[:notes])
        )

        # Position = next available if not provided
        round.position = (args["position"] || args[:position]).to_i if (args["position"] || args[:position]).present?
        round.position ||= (app.interview_rounds.maximum(:position).to_i + 1)

        round.save!

        {
          success: true,
          data: {
            interview_round: {
              id: round.id,
              stage: round.stage,
              stage_name: round.stage_display_name,
              result: round.result,
              scheduled_at: round.scheduled_at,
              completed_at: round.completed_at,
              interviewer: round.interviewer_display,
              duration_minutes: round.duration_minutes
            },
            interview_application: {
              uuid: app.uuid,
              id: app.id
            }
          }
        }
      rescue ActiveRecord::RecordInvalid => e
        { success: false, error: e.record.errors.full_messages.join(", ") }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def parse_time(value)
        return nil if value.blank?
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
