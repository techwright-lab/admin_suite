# frozen_string_literal: true

require "test_helper"

class SignalsDecisioningExecutionReplaySafetyTest < ActiveSupport::TestCase
  test "replaying the same steps is safe (no duplicate records)" do
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

    steps = [
      {
        "step_id" => "create_round_1",
        "action" => "create_round",
        "target" => {},
        "params" => {
          "stage" => "screening",
          "stage_name" => "Phone Screen",
          "scheduled_at" => Time.current.iso8601,
          "duration_minutes" => 30,
          "notes" => "from email"
        },
        "preconditions" => [ "match.matched == true" ],
        "evidence" => [ "foo" ],
        "risk" => "low"
      },
      {
        "step_id" => "company_feedback_offer",
        "action" => "create_company_feedback",
        "target" => {},
        "params" => {
          "feedback_type" => "offer",
          "feedback_text" => "Offer received",
          "rejection_reason" => nil,
          "next_steps" => nil
        },
        "preconditions" => [ "application.company_feedback == null" ],
        "evidence" => [ "foo" ],
        "risk" => "low"
      }
    ]

    steps.each { |s| dispatcher.dispatch(s) }
    round_count_1 = app.interview_rounds.where(source_email_id: email.id).count
    feedback_count_1 = CompanyFeedback.where(interview_application: app).count

    steps.each { |s| dispatcher.dispatch(s) }
    round_count_2 = app.interview_rounds.where(source_email_id: email.id).count
    feedback_count_2 = CompanyFeedback.where(interview_application: app).count

    assert_equal round_count_1, round_count_2
    assert_equal feedback_count_1, feedback_count_2
  end
end
