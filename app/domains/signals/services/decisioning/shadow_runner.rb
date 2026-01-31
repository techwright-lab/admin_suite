# frozen_string_literal: true

module Signals
  module Decisioning
    # Shadow mode runner for the new Facts → Decision contracts.
    #
    # This does NOT execute any plan. It only:
    # - builds DecisionInput
    # - generates a DecisionPlan (currently deterministic baseline)
    # - validates both shapes against schemas
    # - persists them onto SyncedEmail.extracted_data under versioned keys
    class ShadowRunner < ApplicationService
      DECISION_INPUT_SCHEMA_ID = "gleania://signals/contracts/schemas/decision_input.schema.json"
      DECISION_PLAN_SCHEMA_ID = "gleania://signals/contracts/schemas/decision_plan.schema.json"

      DECISION_INPUT_KEY = "decision_input_v1"
      DECISION_PLAN_KEY = "decision_plan_v1"
      DECISION_META_KEY = "decisioning_meta_v1"

      def initialize(synced_email, pipeline_run: nil)
        @synced_email = synced_email
        @pipeline_recorder = Signals::Observability::EmailPipelineRecorder.for_run(pipeline_run)
      end

      def call
        log_info("Shadow decisioning start: synced_email_id=#{synced_email.id} matched=#{synced_email.matched?}")
        builder = Signals::Decisioning::DecisionInputBuilder.new(synced_email)
        base = builder.build_base

        facts =
          if Setting.signals_email_facts_extraction_enabled?
            extractor = Signals::Facts::EmailFactsExtractor.new(synced_email, decision_input_base: base)
            res =
              if pipeline_recorder
                pipeline_recorder.measure(
                  :email_facts_extraction,
                  input_payload: { "synced_email_id" => synced_email.id },
                  output_payload_override: lambda { |r|
                    {
                      "success" => r[:success],
                      "llm_api_log_id" => r[:llm_api_log_id],
                      "kind" => r.dig(:facts, "classification", "kind"),
                      "error" => r[:error]
                    }.compact
                  }
                ) { extractor.call }
              else
                extractor.call
              end

            res[:success] ? res[:facts] : builder.build_fallback_facts(synced_email.interview_application)
          else
            builder.build_fallback_facts(synced_email.interview_application)
          end

        decision_input =
          if pipeline_recorder
            pipeline_recorder.measure(
              :decision_input_build,
              input_payload: { "synced_email_id" => synced_email.id },
              output_payload_override: { "matched" => synced_email.matched? }
            ) { builder.build(facts: facts) }
          else
            builder.build(facts: facts)
          end
        input_errors = schema_validator(DECISION_INPUT_SCHEMA_ID).errors_for(decision_input)
        if input_errors.any?
          log_warning("Shadow decisioning invalid DecisionInput: synced_email_id=#{synced_email.id} errors=#{input_errors.size}")
          pipeline_recorder&.event!(
            event_type: :decision_plan_schema_validate,
            status: :failed,
            output_payload: { "decision_input_error_count" => input_errors.size }
          )
          return persist_errors("decision_input_invalid", input_errors)
        end

        decision_plan =
          if pipeline_recorder
            pipeline_recorder.measure(
              :decision_plan_build,
              input_payload: { "synced_email_id" => synced_email.id },
              output_payload_override: {}
            ) do
              Signals::Decisioning::Planner.new(decision_input).plan
            end
          else
            Signals::Decisioning::Planner.new(decision_input).plan
          end
        plan_errors = schema_validator(DECISION_PLAN_SCHEMA_ID).errors_for(decision_plan)
        if plan_errors.any?
          log_warning("Shadow decisioning invalid DecisionPlan: synced_email_id=#{synced_email.id} errors=#{plan_errors.size}")
          pipeline_recorder&.event!(
            event_type: :decision_plan_schema_validate,
            status: :failed,
            output_payload: { "decision_plan_error_count" => plan_errors.size }
          )
          return persist_errors("decision_plan_invalid", plan_errors)
        end
        pipeline_recorder&.event!(
          event_type: :decision_plan_schema_validate,
          status: :success,
          output_payload: { "decision" => decision_plan["decision"], "steps" => decision_plan.fetch("plan", []).size }
        )

        persist_payloads(decision_input, decision_plan, status: "ok", errors: [])
        log_info("Shadow decisioning ok: synced_email_id=#{synced_email.id} decision=#{decision_plan["decision"]}")
      rescue StandardError => e
        notify_error(
          e,
          context: "signals_decision_shadow_runner",
          severity: "warning",
          user: synced_email&.user,
          synced_email_id: synced_email&.id,
          application_id: synced_email&.interview_application_id
        )
        log_error("Shadow decisioning exception: synced_email_id=#{synced_email&.id} #{e.class}: #{e.message}")
        persist_errors("exception", [ { "message" => e.message, "class" => e.class.name } ])
      end

      private

      attr_reader :synced_email, :pipeline_recorder

      def schema_validator(schema_id)
        Signals::Contracts::Validators::JsonSchemaValidator.new(schema_id: schema_id)
      end

      def persist_payloads(decision_input, decision_plan, status:, errors:)
        existing = synced_email.extracted_data.is_a?(Hash) ? synced_email.extracted_data.deep_dup : {}
        now = Time.current.iso8601

        existing[DECISION_INPUT_KEY] = decision_input
        existing[DECISION_PLAN_KEY] = decision_plan
        existing[DECISION_META_KEY] = {
          "status" => status,
          "errors" => errors,
          "generated_at" => now
        }

        synced_email.update!(extracted_data: existing)
        true
      end

      def persist_errors(status, errors)
        persist_payloads(nil, nil, status: status, errors: errors)
        false
      end
    end
  end
end
