# frozen_string_literal: true

# Background job for extracting actionable signals from synced emails
#
# Runs AI extraction on synced emails to extract company info, recruiter details,
# job information, and suggested actions. Also triggers automated email processors
# to create interview rounds, update statuses, and capture feedback.
#
# @example
#   ProcessSignalExtractionJob.perform_later(synced_email.id)
#
class ProcessSignalExtractionJob < ApplicationJob
  queue_as :default

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound

  # Process the email with AI signal extraction
  #
  # @param synced_email_id [Integer] The synced email ID to process
  # @param run_id [Integer, nil] Optional Signals::EmailPipelineRun id
  # @return [void]
  def perform(synced_email_id, run_id = nil)
    @synced_email = SyncedEmail.find(synced_email_id)
    @run_id = run_id

    new_pipeline_enabled =
      Setting.signals_decision_shadow_enabled? ||
      Setting.signals_decision_execution_enabled? ||
      Setting.signals_email_facts_extraction_enabled?

    run = Signals::EmailPipelineRun.find_by(id: run_id) if run_id.present?
    run ||= Signals::EmailPipelineRun.create!(
      synced_email: @synced_email,
      user: @synced_email.user,
      connected_account: @synced_email.connected_account,
      status: :started,
      trigger: run_id.present? ? "gmail_sync" : "manual",
      mode: "mixed",
      started_at: Time.current,
      metadata: { "source" => "process_signal_extraction_job" }
    )
    recorder = Signals::Observability::EmailPipelineRecorder.for_run(run)

    # Legacy signal extraction is not the same thing as the new Facts/Decision pipeline.
    # If the new pipeline is enabled, we still want to run it even if legacy extraction
    # already ran (or was skipped).
    if @synced_email.extraction_completed? && !new_pipeline_enabled
      recorder&.finish_success!(metadata: { "final" => "skipped", "reason" => "already_extracted" })
      return
    end

    if @synced_email.extraction_status == "skipped" && !new_pipeline_enabled
      recorder&.finish_success!(metadata: { "final" => "skipped", "reason" => "extraction_status_skipped" })
      return
    end

    Rails.logger.info("Processing signal extraction for email #{synced_email_id}")

    legacy_result = nil
    if Setting.signals_email_facts_extraction_enabled?
      # When EmailFacts is enabled, legacy signal extraction is optional and should not block.
      legacy_result = { success: false, skipped: true, reason: "signals_email_facts_extraction_enabled" }
      recorder&.event!(
        event_type: :legacy_signal_extraction,
        status: :skipped,
        input_payload: { "synced_email_id" => synced_email_id },
        output_payload: { "skipped" => true, "reason" => legacy_result[:reason] }
      )
    else
      # Run legacy AI extraction (service handles its own error notification)
      service = Signals::ExtractionService.new(@synced_email)
      legacy_result = recorder&.measure(
        :legacy_signal_extraction,
        input_payload: { "synced_email_id" => synced_email_id, "email_type" => @synced_email.email_type, "matched" => @synced_email.matched? },
        output_payload_override: lambda { |r|
          {
            "success" => r[:success],
            "skipped" => r[:skipped],
            "reason" => r[:reason],
            "error" => r[:error]
          }.compact
        }
      ) { service.extract } || service.extract
    end

    legacy_ok = legacy_result[:success]

    # Always attempt the new pipeline when enabled, even if legacy extraction failed.
    if Setting.signals_decision_shadow_enabled?
      Signals::Decisioning::ShadowRunner.new(@synced_email, pipeline_run: run).call
    end

    # Optional execution mode (guarded by Setting + semantic validation).
    executed = false
    if Setting.signals_decision_execution_enabled?
      executed = Signals::Decisioning::ExecutionRunner.new(@synced_email, pipeline_run: run).call
    end

    # Single-writer gate:
    # - If the new execution runner successfully applied a plan, do NOT also run legacy orchestration.
    # - Otherwise, fall back to the legacy system ONLY if legacy extraction succeeded.
    if executed
      Rails.logger.info("Signals decision execution applied; skipping legacy orchestration for email #{synced_email_id}")
      recorder&.finish_success!(metadata: { "final" => "executed_new" })
      return
    end

    if legacy_ok
      Rails.logger.info("Successfully extracted signals for email #{synced_email_id}")
      @synced_email.reload
      Rails.logger.info("  Company: #{@synced_email.signal_company_name}") if @synced_email.signal_company_name.present?

      recorder&.measure(
        :legacy_orchestrator,
        input_payload: { "synced_email_id" => synced_email_id, "email_type" => @synced_email.email_type, "matched" => @synced_email.matched? },
        output_payload_override: lambda { |r| { "result" => r } }
      ) { process_email_actions(@synced_email) }
      recorder&.finish_success!(metadata: { "final" => "executed_legacy" })
      return
    end

    if legacy_result[:skipped]
      Rails.logger.info("Skipped legacy signal extraction for email #{synced_email_id}: #{legacy_result[:reason]}")
      recorder&.finish_success!(metadata: { "final" => new_pipeline_enabled ? "new_pipeline_no_execution" : "skipped", "reason" => legacy_result[:reason] })
      return
    end

    # Legacy extraction failed and we didn't execute a new plan.
    if new_pipeline_enabled
      Rails.logger.warn("Legacy signal extraction failed but new pipeline enabled; continuing. email=#{synced_email_id} error=#{legacy_result[:error]}")
      recorder&.finish_success!(metadata: { "final" => "new_pipeline_no_execution", "legacy_error" => legacy_result[:error] }.compact)
    else
      Rails.logger.warn("Failed to extract signals for email #{synced_email_id}: #{legacy_result[:error]}")
      recorder&.finish_failed!(RuntimeError.new(legacy_result[:error].to_s), metadata: { "final" => "failed_legacy_extraction" })
    end
  rescue StandardError => e
    begin
      if defined?(recorder) && recorder
        recorder.finish_failed!(e, metadata: { "final" => "exception" })
      end
    rescue StandardError
      # best-effort only
    end
    # Note: Individual services (ExtractionService, processors) handle their own error notifications.
    # This catch is for unexpected errors outside the service calls.
    handle_error(e,
      context: "signal_extraction",
      user: @synced_email&.user,
      synced_email_id: synced_email_id
    )
  end

  private

  # Processes automated actions based on email type
  # Note: Individual processors handle their own error notifications.
  #
  # @param synced_email [SyncedEmail]
  def process_email_actions(synced_email)
    return unless synced_email.matched?

    Rails.logger.info("Processing automated actions for email #{synced_email.id} (type: #{synced_email.email_type})")

    orchestrator_result = Signals::EmailStateOrchestrator.new(synced_email).call

    # Always try to capture feedback if available
    feedback_result = process_company_feedback(synced_email) if synced_email.matched?

    { "orchestrator" => orchestrator_result, "company_feedback" => feedback_result }.compact
  end

  # Processes company feedback capture
  #
  # @param synced_email [SyncedEmail]
  def process_company_feedback(synced_email)
    processor = Signals::CompanyFeedbackProcessor.new(synced_email)
    result = processor.process

    if result[:success]
      Rails.logger.info("Captured company feedback from email #{synced_email.id}")
    elsif result[:skipped]
      # Don't log skipped feedback - this is common
    else
      Rails.logger.warn("Failed to capture company feedback: #{result[:error]}")
    end
    result
  end
end
