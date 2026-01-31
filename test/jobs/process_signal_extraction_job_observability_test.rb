# frozen_string_literal: true

require "test_helper"

class ProcessSignalExtractionJobObservabilityTest < ActiveJob::TestCase
  test "threads run_id and emits pipeline events" do
    Setting.set(name: "signals_decision_shadow_enabled", value: true)
    Setting.set(name: "signals_decision_execution_enabled", value: false)
    Setting.set(name: "signals_email_facts_extraction_enabled", value: false)

    app = create(:interview_application)
    email = create(:synced_email, :processed, interview_application: app, extraction_status: "pending")

    run = Signals::EmailPipelineRun.create!(
      synced_email: email,
      user: email.user,
      connected_account: email.connected_account,
      status: :started,
      trigger: "gmail_sync",
      mode: "mixed",
      started_at: Time.current
    )

    extraction_new = Signals::ExtractionService.singleton_class.instance_method(:new)
    legacy_new = Signals::EmailStateOrchestrator.singleton_class.instance_method(:new)
    feedback_new = Signals::CompanyFeedbackProcessor.singleton_class.instance_method(:new)

    Signals::ExtractionService.singleton_class.define_method(:new) { |_e| Struct.new(:extract).new({ success: true }) }
    Signals::EmailStateOrchestrator.singleton_class.define_method(:new) { |_e| Struct.new(:call).new({ success: true }) }
    Signals::CompanyFeedbackProcessor.singleton_class.define_method(:new) { |_e| Struct.new(:process).new({ skipped: true }) }

    begin
      ProcessSignalExtractionJob.new.perform(email.id, run.id)
    ensure
      Signals::ExtractionService.singleton_class.define_method(:new, extraction_new)
      Signals::EmailStateOrchestrator.singleton_class.define_method(:new, legacy_new)
      Signals::CompanyFeedbackProcessor.singleton_class.define_method(:new, feedback_new)
    end

    run.reload
    assert_equal "success", run.status
    assert run.completed_at.present?
    assert run.duration_ms.present?

    events = run.events.in_order.to_a
    assert events.any?

    event_types = events.map(&:event_type)
    assert_includes event_types, "legacy_signal_extraction"
    assert_includes event_types, "decision_input_build"
    assert_includes event_types, "decision_plan_build"
    assert_includes event_types, "decision_plan_schema_validate"
    assert_includes event_types, "legacy_orchestrator"

    assert_equal events.map(&:step_order), events.map(&:step_order).uniq, "step_order should be unique per run"
  end
end
