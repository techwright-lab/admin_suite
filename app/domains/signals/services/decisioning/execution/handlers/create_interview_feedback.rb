# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class CreateInterviewFeedback < BaseHandler
          def call(step)
            params = step["params"] || {}
            round = resolve_round(step["target"] || {})
            return { "action" => "create_interview_feedback", "status" => "no_round_resolved" } unless round
            existing = InterviewFeedback.find_by(interview_round_id: round.id)
            if existing
              return {
                "action" => "create_interview_feedback",
                "status" => "already_exists",
                "round_id" => round.id,
                "feedback_id" => existing.id
              }
            end

            fb = InterviewFeedback.create!(
              interview_round: round,
              went_well: params["went_well"],
              to_improve: params["to_improve"],
              ai_summary: params["ai_summary"],
              interviewer_notes: params["interviewer_notes"],
              recommended_action: params["recommended_action"]
            )

            { "action" => "create_interview_feedback", "round_id" => round.id, "feedback_id" => fb.id }
          end
        end
      end
    end
  end
end
