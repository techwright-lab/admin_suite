# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: fetch feedback for an interview round (if any).
    class GetInterviewFeedbackTool < BaseTool
      def call(args:, tool_execution:)
        round_id = (args["interview_round_id"] || args[:interview_round_id]).to_i
        return { success: false, error: "interview_round_id is required" } if round_id <= 0

        round = InterviewRound.includes(:interview_feedback, :interview_application).find_by(id: round_id)
        return { success: false, error: "Interview round not found" } if round.nil?
        return { success: false, error: "Not authorized" } unless round.interview_application.user_id == user.id

        fb = round.interview_feedback
        return { success: true, data: { interview_round_id: round.id, interview_feedback: nil } } if fb.nil?

        {
          success: true,
          data: {
            interview_round_id: round.id,
            interview_feedback: {
              id: fb.id,
              went_well: fb.went_well,
              to_improve: fb.to_improve,
              self_reflection: fb.self_reflection,
              interviewer_notes: fb.interviewer_notes,
              recommended_action: fb.recommended_action,
              tags: fb.tag_list,
              ai_summary: fb.ai_summary
            }
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
