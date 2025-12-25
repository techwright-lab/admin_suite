# frozen_string_literal: true

module Assistant
  module Tools
    # Write: create or update manual interview feedback for a round.
    class UpsertInterviewFeedbackTool < BaseTool
      def call(args:, tool_execution:)
        round_id = (args["interview_round_id"] || args[:interview_round_id]).to_i
        return { success: false, error: "interview_round_id is required" } if round_id <= 0

        round = InterviewRound.includes(:interview_application, :interview_feedback).find_by(id: round_id)
        return { success: false, error: "Interview round not found" } if round.nil?
        return { success: false, error: "Not authorized" } unless round.interview_application.user_id == user.id

        fb = round.interview_feedback || round.build_interview_feedback

        fb.went_well = args["went_well"] || args[:went_well] if args.key?("went_well") || args.key?(:went_well)
        fb.to_improve = args["to_improve"] || args[:to_improve] if args.key?("to_improve") || args.key?(:to_improve)
        fb.self_reflection = args["self_reflection"] || args[:self_reflection] if args.key?("self_reflection") || args.key?(:self_reflection)
        fb.interviewer_notes = args["interviewer_notes"] || args[:interviewer_notes] if args.key?("interviewer_notes") || args.key?(:interviewer_notes)
        fb.recommended_action = args["recommended_action"] || args[:recommended_action] if args.key?("recommended_action") || args.key?(:recommended_action)

        tags = args["tags"] || args[:tags]
        fb.tag_list = tags if tags.present?

        fb.save!

        {
          success: true,
          data: {
            interview_round_id: round.id,
            interview_feedback_id: fb.id
          }
        }
      rescue ActiveRecord::RecordInvalid => e
        { success: false, error: e.record.errors.full_messages.join(", ") }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
