# frozen_string_literal: true

module Signals
  module Decisioning
    module Rules
      class RoundFeedbackRule < BaseRule
        def call
          return nil unless matched?
          return nil unless kind == "round_feedback"

          rf = input.dig("facts", "round_feedback") || {}
          result = rf["result"].to_s
          evidence = Array(rf["evidence"]).first(3)
          return { decision: "noop", reason: "round_feedback_no_evidence" } if evidence.empty?

          mapped = %w[passed failed waitlisted cancelled].include?(result) ? result : nil
          return { decision: "noop", reason: "round_feedback_unknown_result" } unless mapped

          steps = [
            step_factory.set_round_result(
              step_id: "set_round_result",
              selector: "latest_pending",
              result: mapped,
              completed_at: input.dig("event", "email_date"),
              preconditions: [ "application.rounds_recent.any(result==pending) == true" ],
              evidence: evidence,
              risk: mapped == "failed" ? "high" : "low"
            )
          ]

          if rf.dig("feedback", "has_detailed_feedback")
            fb_text = rf.dig("feedback", "full_feedback_text").to_s
            fb_evidence = fb_text.present? ? [ fb_text ] : evidence.first(1)

            steps << step_factory.create_interview_feedback(
              step_id: "create_interview_feedback",
              selector: "latest_pending",
              params: {
                "went_well" => Array(rf.dig("feedback", "strengths")).map { |s| "• #{s}" }.join("\n").presence,
                "to_improve" => Array(rf.dig("feedback", "improvements")).map { |s| "• #{s}" }.join("\n").presence,
                "ai_summary" => rf.dig("feedback", "summary"),
                "interviewer_notes" => rf.dig("feedback", "full_feedback_text"),
                "recommended_action" => default_recommended_action(mapped, rf)
              },
              preconditions: [ "round.interview_feedback == null" ],
              evidence: fb_evidence,
              risk: "low"
            )
          end

          { decision: "apply", confidence: 0.7, reasons: [ "round_feedback_kind" ], steps: steps }
        end

        private

        def default_recommended_action(result, round_feedback)
          case result
          when "passed"
            if round_feedback.dig("next_steps", "has_next_round")
              "Prepare for #{round_feedback.dig("next_steps", "next_round_type") || "next round"}"
            else
              "Follow up on next steps"
            end
          when "failed"
            "Review feedback and apply learnings to future interviews"
          when "waitlisted"
            "Follow up in 1-2 weeks if no update"
          else
            nil
          end
        end
      end
    end
  end
end
