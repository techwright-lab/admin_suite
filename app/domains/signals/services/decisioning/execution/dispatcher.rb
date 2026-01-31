# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      class Dispatcher
        def initialize(synced_email, pipeline_recorder: nil)
          @synced_email = synced_email
          @pipeline_recorder = pipeline_recorder
        end

        def dispatch(step)
          action = step["action"].to_s
          return nil if action == "noop"

          if requires_application?(action) && !synced_email.matched?
            res = {
              "step_id" => step["step_id"],
              "action" => action,
              "status" => "skipped_no_application"
            }
            emit_skipped_step_event(action, step, res)
            return res
          end

          preconditions = Array(step["preconditions"])
          guard = Signals::Decisioning::Execution::PreconditionEvaluator.evaluate_all(preconditions, synced_email: synced_email, step: step)
          unless guard[:ok]
            res = {
              "step_id" => step["step_id"],
              "action" => action,
              "status" => "skipped_precondition_failed",
              "failed_preconditions" => guard[:failed],
              "unknown_preconditions" => guard[:unknown]
            }
            emit_skipped_step_event(action, step, res)
            return res
          end

          handler_class = handler_for(action)
          unless handler_class
            res = { "step_id" => step["step_id"], "status" => "skipped_unknown_action", "action" => action }
            emit_skipped_step_event(action, step, res)
            return res
          end

          handler = handler_class.new(synced_email)

          if pipeline_recorder
            pipeline_recorder.measure(
              :"execute_#{action}",
              input_payload: {
                "step_id" => step["step_id"],
                "action" => action,
                "target" => step["target"],
                "params" => step["params"]
              },
              output_payload_override: ->(result) { { "result" => result } }
            ) { handler.call(step) }
          else
            handler.call(step)
          end
        end

        private

        attr_reader :synced_email, :pipeline_recorder

        def emit_skipped_step_event(action, step, result)
          return unless pipeline_recorder
          return unless Signals::EmailPipelineEvent.event_types.key?("execute_#{action}")

          pipeline_recorder.event!(
            event_type: :"execute_#{action}",
            status: :skipped,
            input_payload: {
              "step_id" => step["step_id"],
              "action" => action,
              "target" => step["target"],
              "params" => step["params"],
              "preconditions" => step["preconditions"]
            },
            output_payload: { "result" => result }
          )
        end

        def handler_for(action)
          case action
          when "set_pipeline_stage" then Signals::Decisioning::Execution::Handlers::SetPipelineStage
          when "set_application_status" then Signals::Decisioning::Execution::Handlers::SetApplicationStatus
          when "create_round" then Signals::Decisioning::Execution::Handlers::CreateRound
          when "update_round" then Signals::Decisioning::Execution::Handlers::UpdateRound
          when "set_round_result" then Signals::Decisioning::Execution::Handlers::SetRoundResult
          when "create_interview_feedback" then Signals::Decisioning::Execution::Handlers::CreateInterviewFeedback
          when "create_company_feedback" then Signals::Decisioning::Execution::Handlers::CreateCompanyFeedback
          when "create_opportunity" then Signals::Decisioning::Execution::Handlers::CreateOpportunity
          when "upsert_job_listing_from_url" then Signals::Decisioning::Execution::Handlers::UpsertJobListingFromUrl
          when "attach_job_listing_to_opportunity" then Signals::Decisioning::Execution::Handlers::AttachJobListingToOpportunity
          when "enqueue_scrape_job_listing" then Signals::Decisioning::Execution::Handlers::EnqueueScrapeJobListing
          else nil
          end
        end

        def requires_application?(action)
          %w[
            set_pipeline_stage
            set_application_status
            create_round
            update_round
            set_round_result
            create_interview_feedback
            create_company_feedback
          ].include?(action)
        end
      end
    end
  end
end
