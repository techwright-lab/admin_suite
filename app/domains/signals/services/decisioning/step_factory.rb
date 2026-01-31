# frozen_string_literal: true

module Signals
  module Decisioning
    # Helper for consistent DecisionPlan step construction.
    class StepFactory
      def initialize(application_id:, synced_email_id:, email_date: nil)
        @application_id = application_id
        @synced_email_id = synced_email_id
        @email_date = email_date
      end

      def target(selector:)
        {
          "application_id" => application_id,
          "round" => {
            "selector" => selector,
            "id" => nil,
            "scheduled_at" => nil,
            "window_minutes" => 0,
            "stage" => nil,
            "result" => nil
          }
        }
      end

      def step(step_id:, action:, target:, params: {}, preconditions: [], evidence: [], risk: "low", include_source: false)
        merged_params = params || {}
        merged_params = merged_params.merge("source" => { "synced_email_id" => synced_email_id }) if include_source

        {
          "step_id" => step_id,
          "action" => action,
          "target" => target,
          "params" => merged_params,
          "preconditions" => Array(preconditions),
          "evidence" => Array(evidence),
          "risk" => risk.to_s
        }
      end

      def create_round(step_id:, params:, preconditions:, evidence:, risk: "low")
        step(
          step_id: step_id,
          action: "create_round",
          target: target(selector: "none"),
          params: params,
          preconditions: preconditions,
          evidence: evidence,
          risk: risk,
          include_source: true
        )
      end

      def set_pipeline_stage(step_id:, selector:, stage:, preconditions:, evidence:, risk: "low")
        step(
          step_id: step_id,
          action: "set_pipeline_stage",
          target: target(selector: selector),
          params: { "stage" => stage },
          preconditions: preconditions,
          evidence: evidence,
          risk: risk
        )
      end

      def set_application_status(step_id:, status:, preconditions:, evidence:, risk: "low")
        step(
          step_id: step_id,
          action: "set_application_status",
          target: target(selector: "none"),
          params: { "status" => status },
          preconditions: preconditions,
          evidence: evidence,
          risk: risk
        )
      end

      def set_round_result(step_id:, selector:, result:, completed_at:, preconditions:, evidence:, risk: "low")
        step(
          step_id: step_id,
          action: "set_round_result",
          target: target(selector: selector),
          params: { "result" => result, "completed_at" => completed_at || email_date },
          preconditions: preconditions,
          evidence: evidence,
          risk: risk,
          include_source: true
        )
      end

      def create_interview_feedback(step_id:, selector:, params:, preconditions:, evidence:, risk: "low")
        step(
          step_id: step_id,
          action: "create_interview_feedback",
          target: target(selector: selector),
          params: params.merge("round_selector" => selector),
          preconditions: preconditions,
          evidence: evidence,
          risk: risk,
          include_source: true
        )
      end

      def create_company_feedback(step_id:, params:, preconditions:, evidence:, risk: "low")
        step(
          step_id: step_id,
          action: "create_company_feedback",
          target: target(selector: "none"),
          params: params,
          preconditions: preconditions,
          evidence: evidence,
          risk: risk,
          include_source: true
        )
      end

      private

      attr_reader :application_id, :synced_email_id, :email_date
    end
  end
end
