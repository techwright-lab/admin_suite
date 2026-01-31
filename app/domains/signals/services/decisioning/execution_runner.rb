# frozen_string_literal: true

module Signals
  module Decisioning
    # Executes a DecisionPlan with guardrails.
    #
    # This is intentionally conservative. If anything is invalid, it fails closed.
    class ExecutionRunner < ApplicationService
      DECISION_INPUT_SCHEMA_ID = "gleania://signals/contracts/schemas/decision_input.schema.json"
      DECISION_PLAN_SCHEMA_ID = "gleania://signals/contracts/schemas/decision_plan.schema.json"
      EMAIL_FACTS_SCHEMA_ID = "gleania://signals/contracts/schemas/components/facts/email_facts.schema.json"

      EXECUTION_META_KEY = "decision_execution_v1"

      def initialize(synced_email, pipeline_run: nil)
        @synced_email = synced_email
        @pipeline_recorder = Signals::Observability::EmailPipelineRecorder.for_run(pipeline_run)
      end

      def call
        return false unless Setting.signals_decision_execution_enabled?

        log_info("Execution start: synced_email_id=#{synced_email.id} matched=#{synced_email.matched?}")
        builder = Signals::Decisioning::DecisionInputBuilder.new(synced_email)
        base = builder.build_base
        facts = facts_for_execution(builder, base)
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
        unless schema_valid?(DECISION_INPUT_SCHEMA_ID, decision_input)
          errors = schema_errors(DECISION_INPUT_SCHEMA_ID, decision_input)
          log_warning("Execution invalid DecisionInput: synced_email_id=#{synced_email.id} errors=#{errors.size}")
          pipeline_recorder&.event!(
            event_type: :decision_plan_schema_validate,
            status: :failed,
            output_payload: { "decision_input_error_count" => errors.size }
          )
          return persist(status: "decision_input_invalid", errors: errors)
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
        unless schema_valid?(DECISION_PLAN_SCHEMA_ID, decision_plan)
          errors = schema_errors(DECISION_PLAN_SCHEMA_ID, decision_plan)
          log_warning("Execution invalid DecisionPlan: synced_email_id=#{synced_email.id} errors=#{errors.size}")
          pipeline_recorder&.event!(
            event_type: :decision_plan_schema_validate,
            status: :failed,
            output_payload: { "decision_plan_error_count" => errors.size }
          )
          return persist(status: "decision_plan_invalid", errors: errors)
        end
        pipeline_recorder&.event!(
          event_type: :decision_plan_schema_validate,
          status: :success,
          output_payload: { "decision" => decision_plan["decision"], "steps" => decision_plan.fetch("plan", []).size }
        )

        semantic_errors =
          if pipeline_recorder
            pipeline_recorder.measure(
              :decision_plan_semantic_validate,
              input_payload: { "synced_email_id" => synced_email.id },
              output_payload_override: lambda { |errs| { "error_count" => Array(errs).size } }
            ) { Signals::Decisioning::SemanticValidator.new(decision_input, decision_plan).errors }
          else
            Signals::Decisioning::SemanticValidator.new(decision_input, decision_plan).errors
          end
        if semantic_errors.any?
          log_warning("Execution semantic invalid: synced_email_id=#{synced_email.id} errors=#{semantic_errors.size}")
          return persist(status: "semantic_invalid", errors: semantic_errors)
        end

        applied =
          if pipeline_recorder
            pipeline_recorder.measure(
              :execution_dispatch,
              input_payload: { "synced_email_id" => synced_email.id },
              output_payload_override: {}
            ) { execute_steps(decision_plan) }
          else
            execute_steps(decision_plan)
          end
        log_info("Execution executed: synced_email_id=#{synced_email.id} applied_steps=#{applied.size}")
        persist(status: "executed", errors: [], applied: applied)
      rescue StandardError => e
        notify_error(
          e,
          context: "signals_decision_execution_runner",
          severity: "error",
          user: synced_email&.user,
          synced_email_id: synced_email&.id,
          application_id: synced_email&.interview_application_id
        )
        log_error("Execution exception: synced_email_id=#{synced_email&.id} #{e.class}: #{e.message}")
        persist(status: "exception", errors: [ { "message" => e.message, "class" => e.class.name } ])
      end

      private

      attr_reader :synced_email, :pipeline_recorder

      def facts_for_execution(builder, base)
        app = synced_email.interview_application

        unless Setting.signals_email_facts_extraction_enabled?
          return builder.build_fallback_facts(app)
        end

        persisted = synced_email.extracted_data.is_a?(Hash) ? synced_email.extracted_data[Signals::Facts::EmailFactsExtractor::FACTS_KEY] : nil
        persisted_meta = synced_email.extracted_data.is_a?(Hash) ? synced_email.extracted_data[Signals::Facts::EmailFactsExtractor::FACTS_META_KEY] : nil

        if persisted.is_a?(Hash) && persisted_meta.is_a?(Hash) && persisted_meta["status"] == "ok" && schema_valid?(EMAIL_FACTS_SCHEMA_ID, persisted)
          pipeline_recorder&.event!(
            event_type: :email_facts_extraction,
            status: :success,
            output_payload: { "source" => "persisted", "kind" => persisted.dig("classification", "kind") }.compact
          )
          return persisted
        end

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
        res[:success] ? res[:facts] : builder.build_fallback_facts(app)
      end

      def schema_valid?(schema_id, payload)
        schema_errors(schema_id, payload).empty?
      end

      def schema_errors(schema_id, payload)
        Signals::Contracts::Validators::JsonSchemaValidator.new(schema_id: schema_id).errors_for(payload)
      end

      def execute_steps(plan)
        dispatcher = Signals::Decisioning::Execution::Dispatcher.new(synced_email, pipeline_recorder: pipeline_recorder)
        plan.fetch("plan", []).filter_map { |step| dispatcher.dispatch(step) }
      end

      def persist(status:, errors:, applied: nil)
        existing = synced_email.extracted_data.is_a?(Hash) ? synced_email.extracted_data.deep_dup : {}
        existing[EXECUTION_META_KEY] = {
          "status" => status,
          "errors" => errors,
          "applied" => applied,
          "executed_at" => Time.current.iso8601
        }
        synced_email.update!(extracted_data: existing)
        status == "executed"
      end
    end
  end
end
