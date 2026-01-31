# frozen_string_literal: true

require "test_helper"

class ProcessSignalExtractionJobTest < ActiveJob::TestCase
  test "skips legacy orchestration when decision execution applies" do
    Setting.set(name: "signals_decision_execution_enabled", value: true)

    app = create(:interview_application)
    email = create(:synced_email, :processed, interview_application: app, extraction_status: "pending")

    extraction_new = Signals::ExtractionService.singleton_class.instance_method(:new)
    execution_new = Signals::Decisioning::ExecutionRunner.singleton_class.instance_method(:new)
    legacy_new = Signals::EmailStateOrchestrator.singleton_class.instance_method(:new)

    Signals::ExtractionService.singleton_class.define_method(:new) { |_e| Struct.new(:extract).new({ success: true }) }
    Signals::Decisioning::ExecutionRunner.singleton_class.define_method(:new) { |_e, **_kw| Struct.new(:call).new(true) }
    Signals::EmailStateOrchestrator.singleton_class.define_method(:new) { |_e| raise "legacy_orchestrator_should_not_run" }

    begin
      perform_enqueued_jobs { ProcessSignalExtractionJob.perform_later(email.id) }
    ensure
      Signals::ExtractionService.singleton_class.define_method(:new, extraction_new)
      Signals::Decisioning::ExecutionRunner.singleton_class.define_method(:new, execution_new)
      Signals::EmailStateOrchestrator.singleton_class.define_method(:new, legacy_new)
    end
  end

  test "falls back to legacy orchestration when decision execution does not apply" do
    Setting.set(name: "signals_decision_execution_enabled", value: true)

    app = create(:interview_application)
    email = create(:synced_email, :processed, interview_application: app, extraction_status: "pending")

    ran_legacy = false

    extraction_new = Signals::ExtractionService.singleton_class.instance_method(:new)
    execution_new = Signals::Decisioning::ExecutionRunner.singleton_class.instance_method(:new)
    legacy_new = Signals::EmailStateOrchestrator.singleton_class.instance_method(:new)
    feedback_new = Signals::CompanyFeedbackProcessor.singleton_class.instance_method(:new)

    Signals::ExtractionService.singleton_class.define_method(:new) { |_e| Struct.new(:extract).new({ success: true }) }
    Signals::Decisioning::ExecutionRunner.singleton_class.define_method(:new) { |_e, **_kw| Struct.new(:call).new(false) }
    Signals::EmailStateOrchestrator.singleton_class.define_method(:new) { |_e| Struct.new(:call).new(ran_legacy = true) }
    Signals::CompanyFeedbackProcessor.singleton_class.define_method(:new) { |_e| Struct.new(:process).new({ skipped: true }) }

    begin
      perform_enqueued_jobs { ProcessSignalExtractionJob.perform_later(email.id) }
    ensure
      Signals::ExtractionService.singleton_class.define_method(:new, extraction_new)
      Signals::Decisioning::ExecutionRunner.singleton_class.define_method(:new, execution_new)
      Signals::EmailStateOrchestrator.singleton_class.define_method(:new, legacy_new)
      Signals::CompanyFeedbackProcessor.singleton_class.define_method(:new, feedback_new)
    end

    assert ran_legacy
  end

  test "runs shadow decisioning even when legacy extraction fails" do
    Setting.set(name: "signals_decision_shadow_enabled", value: true)
    Setting.set(name: "signals_decision_execution_enabled", value: false)
    Setting.set(name: "signals_email_facts_extraction_enabled", value: false)

    app = create(:interview_application)
    email = create(:synced_email, :processed, interview_application: app, extraction_status: "pending")

    shadow_ran = false

    extraction_new = Signals::ExtractionService.singleton_class.instance_method(:new)
    shadow_new = Signals::Decisioning::ShadowRunner.singleton_class.instance_method(:new)
    legacy_new = Signals::EmailStateOrchestrator.singleton_class.instance_method(:new)

    Signals::ExtractionService.singleton_class.define_method(:new) do |_e|
      Struct.new(:extract).new({ success: false, error: "All providers failed" })
    end
    Signals::Decisioning::ShadowRunner.singleton_class.define_method(:new) do |_e, **_kw|
      Struct.new(:call).new(shadow_ran = true)
    end
    Signals::EmailStateOrchestrator.singleton_class.define_method(:new) { |_e| raise "legacy_orchestrator_should_not_run" }

    begin
      perform_enqueued_jobs { ProcessSignalExtractionJob.perform_later(email.id) }
    ensure
      Signals::ExtractionService.singleton_class.define_method(:new, extraction_new)
      Signals::Decisioning::ShadowRunner.singleton_class.define_method(:new, shadow_new)
      Signals::EmailStateOrchestrator.singleton_class.define_method(:new, legacy_new)
    end

    assert shadow_ran
  end
end
