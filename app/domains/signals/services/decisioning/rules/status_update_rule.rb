# frozen_string_literal: true

module Signals
  module Decisioning
    module Rules
      class StatusUpdateRule < BaseRule
        def call
          return nil unless matched?
          return nil unless kind == "status_update"

          status_change = input.dig("facts", "status_change") || {}
          type = status_change["type"].to_s
          evidence = Array(status_change["evidence"]).first(3)
          return { decision: "noop", reason: "status_update_no_evidence" } if evidence.empty?

          case type
          when "rejection"
            steps = [
              step_factory.set_application_status(
                step_id: "set_status_rejected",
                status: "rejected",
                preconditions: [ "application.status == active" ],
                evidence: evidence,
                risk: "high"
              ),
              step_factory.set_pipeline_stage(
                step_id: "set_pipeline_closed",
                selector: "none",
                stage: "closed",
                preconditions: [ "application.pipeline_stage != closed" ],
                evidence: evidence.first(1),
                risk: "high"
              )
            ]
            { decision: "apply", confidence: 0.75, reasons: [ "rejection_status_change" ], steps: steps }
          when "offer"
            steps = [
              step_factory.set_pipeline_stage(
                step_id: "set_pipeline_offer",
                selector: "none",
                stage: "offer",
                preconditions: [ "application.pipeline_stage != offer" ],
                evidence: evidence,
                risk: "medium"
              ),
              step_factory.create_company_feedback(
                step_id: "create_company_feedback_offer",
                params: {
                  "feedback_type" => "offer",
                  "feedback_text" => build_offer_feedback_text(status_change),
                  "rejection_reason" => nil,
                  "next_steps" => status_change.dig("offer_details", "next_steps")
                },
                preconditions: [ "application.company_feedback == null" ],
                evidence: evidence.first(2),
                risk: "low"
              )
            ]
            { decision: "apply", confidence: 0.7, reasons: [ "offer_status_change" ], steps: steps }
          when "on_hold"
            steps = [
              step_factory.set_application_status(
                step_id: "set_status_on_hold",
                status: "on_hold",
                preconditions: [ "application.status == active" ],
                evidence: evidence,
                risk: "medium"
              )
            ]
            { decision: "apply", confidence: 0.65, reasons: [ "on_hold_status_change" ], steps: steps }
          when "withdrawal"
            steps = [
              step_factory.set_application_status(
                step_id: "set_status_withdrawn",
                status: "withdrawn",
                preconditions: [ "application.status == active" ],
                evidence: evidence,
                risk: "medium"
              )
            ]
            { decision: "apply", confidence: 0.65, reasons: [ "withdrawal_status_change" ], steps: steps }
          else
            { decision: "noop", reason: "status_update_no_change" }
          end
        end

        private

        def build_offer_feedback_text(status_change)
          role = status_change.dig("offer_details", "role_title")
          deadline = status_change.dig("offer_details", "response_deadline")
          start = status_change.dig("offer_details", "start_date")
          parts = []
          parts << "Offer received#{role ? " for #{role}" : ""}."
          parts << "Respond by: #{deadline}" if deadline.present?
          parts << "Start date: #{start}" if start.present?
          parts.join("\n")
        end
      end
    end
  end
end
