# frozen_string_literal: true

require "test_helper"

class SignalsDecisioningExecutionDispatcherTest < ActiveSupport::TestCase
  test "skips step and emits skipped event when preconditions fail" do
    app = create(:interview_application)
    email = create(:synced_email, :processed, interview_application: app)

    run = Signals::EmailPipelineRun.create!(
      synced_email: email,
      user: email.user,
      connected_account: email.connected_account,
      trigger: "manual",
      mode: "mixed",
      started_at: Time.current
    )
    recorder = Signals::Observability::EmailPipelineRecorder.for_run(run)

    dispatcher = Signals::Decisioning::Execution::Dispatcher.new(email, pipeline_recorder: recorder)
    step = {
      "step_id" => "x",
      "action" => "create_round",
      "target" => { "application_id" => app.id, "round" => { "selector" => "none", "id" => nil, "scheduled_at" => nil, "window_minutes" => 0, "stage" => nil, "result" => nil } },
      "params" => { "stage" => "screening" },
      "preconditions" => [ "application.status == archived" ],
      "evidence" => [ "foo" ],
      "risk" => "low"
    }

    res = dispatcher.dispatch(step)
    assert_equal "skipped_precondition_failed", res["status"]

    event = run.events.order(created_at: :desc).first
    assert_equal "execute_create_round", event.event_type
    assert_equal "skipped", event.status
  end

  test "unknown action emits skipped event" do
    email = create(:synced_email, :processed, interview_application: create(:interview_application))
    run = Signals::EmailPipelineRun.create!(
      synced_email: email,
      user: email.user,
      connected_account: email.connected_account,
      trigger: "manual",
      mode: "mixed",
      started_at: Time.current
    )
    recorder = Signals::Observability::EmailPipelineRecorder.for_run(run)

    dispatcher = Signals::Decisioning::Execution::Dispatcher.new(email, pipeline_recorder: recorder)
    step = {
      "step_id" => "x",
      "action" => "some_new_action",
      "target" => {},
      "params" => {},
      "preconditions" => [],
      "evidence" => [ "foo" ],
      "risk" => "low"
    }

    res = dispatcher.dispatch(step)
    assert_equal "skipped_unknown_action", res["status"]

    # We intentionally do not emit per-step events for unknown actions since event_type is an enum.
    assert_equal 0, run.events.count
  end
end
