# frozen_string_literal: true

module Signals
  module Decisioning
    module Rules
      class SchedulingRule < BaseRule
        def call
          return nil unless matched?
          return nil unless kind == "scheduling"

          scheduling = input.dig("facts", "scheduling") || {}
          evidence = Array(scheduling["evidence"]).first(3)
          return { decision: "noop", reason: "scheduling_no_evidence" } if evidence.empty?

          stage = scheduling["stage"] || "screening"

          steps = [
            step_factory.create_round(
              step_id: "create_round_1",
              params: {
                "stage" => stage,
                "stage_name" => scheduling["stage_name"],
                "scheduled_at" => scheduling["scheduled_at"],
                "duration_minutes" => scheduling["duration_minutes"].to_i.nonzero? || 30,
                "interviewer_name" => scheduling["interviewer_name"],
                "interviewer_role" => scheduling["interviewer_role"],
                "video_link" => scheduling["video_link"],
                "location" => scheduling["location"],
                "phone_number" => scheduling["phone_number"],
                "notes" => "📬 Created from email signal"
              },
              preconditions: [ "match.matched == true" ],
              evidence: evidence,
              risk: "low"
            ),
            step_factory.set_pipeline_stage(
              step_id: "set_pipeline_from_round",
              selector: "latest",
              stage: (stage == "screening" ? "screening" : "interviewing"),
              preconditions: [ "application.pipeline_stage != closed" ],
              evidence: evidence.first(1),
              risk: "low"
            )
          ]

          { decision: "apply", confidence: 0.6, reasons: [ "scheduling_kind" ], steps: steps }
        end
      end
    end
  end
end
