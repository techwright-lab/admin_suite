# frozen_string_literal: true

require "test_helper"

class SignalsDecisioningExecutionHandlersIdempotencyTest < ActiveSupport::TestCase
  test "CreateRound is idempotent for the same email" do
    app = create(:interview_application)
    email = create(:synced_email, :processed, interview_application: app)

    handler = Signals::Decisioning::Execution::Handlers::CreateRound.new(email)
    step = {
      "step_id" => "create_round_1",
      "action" => "create_round",
      "target" => {},
      "params" => {
        "stage" => "screening",
        "stage_name" => "Phone Screen",
        "scheduled_at" => Time.current.iso8601,
        "duration_minutes" => 30,
        "notes" => "from email"
      }
    }

    res1 = handler.call(step)
    assert_equal "create_round", res1["action"]
    assert res1["round_id"].present?

    res2 = handler.call(step)
    assert_equal "already_exists", res2["status"]

    assert_equal 1, app.interview_rounds.where(source_email_id: email.id).count
  end

  test "UpdateRound does not duplicate notes_append on re-run" do
    app = create(:interview_application)
    email = create(:synced_email, :processed, interview_application: app)
    round = create(:interview_round, interview_application: app, notes: "hello", source_email_id: nil)

    handler = Signals::Decisioning::Execution::Handlers::UpdateRound.new(email)
    step = {
      "step_id" => "update_round_1",
      "action" => "update_round",
      "target" => { "application_id" => app.id, "round" => { "selector" => "by_id", "id" => round.id } },
      "params" => { "notes_append" => "appended" }
    }

    handler.call(step)
    handler.call(step)

    round.reload
    assert_includes round.notes, "hello"
    assert_equal 1, round.notes.scan("appended").size
  end

  test "SetRoundResult is idempotent for the same email and same result" do
    app = create(:interview_application)
    email = create(:synced_email, :processed, interview_application: app)
    round = create(:interview_round, interview_application: app, result: :pending, source_email_id: nil)

    handler = Signals::Decisioning::Execution::Handlers::SetRoundResult.new(email)
    step = {
      "step_id" => "set_round_result",
      "action" => "set_round_result",
      "target" => { "application_id" => app.id, "round" => { "selector" => "by_id", "id" => round.id } },
      "params" => { "result" => "passed", "completed_at" => Time.current.iso8601 }
    }

    res1 = handler.call(step)
    assert_equal "passed", res1["result"]

    res2 = handler.call(step)
    assert_equal "already_set", res2["status"]
  end

  test "CreateCompanyFeedback returns already_exists on re-run for same email" do
    app = create(:interview_application)
    email = create(:synced_email, :processed, interview_application: app)

    handler = Signals::Decisioning::Execution::Handlers::CreateCompanyFeedback.new(email)
    step = {
      "step_id" => "create_company_feedback",
      "action" => "create_company_feedback",
      "target" => {},
      "params" => {
        "feedback_type" => "offer",
        "feedback_text" => "Offer received",
        "rejection_reason" => nil,
        "next_steps" => "Respond in 3 days"
      }
    }

    res1 = handler.call(step)
    assert_equal "create_company_feedback", res1["action"]
    assert res1["feedback_id"].present?

    res2 = handler.call(step)
    assert_equal "already_exists", res2["status"]
    assert_equal res1["feedback_id"], res2["feedback_id"]
  end

  test "CreateInterviewFeedback returns already_exists on re-run" do
    app = create(:interview_application)
    email = create(:synced_email, :processed, interview_application: app)
    round = create(:interview_round, interview_application: app, result: :pending)

    handler = Signals::Decisioning::Execution::Handlers::CreateInterviewFeedback.new(email)
    step = {
      "step_id" => "create_interview_feedback",
      "action" => "create_interview_feedback",
      "target" => { "application_id" => app.id, "round" => { "selector" => "by_id", "id" => round.id } },
      "params" => {
        "round_selector" => "by_id",
        "went_well" => "x",
        "to_improve" => "y",
        "ai_summary" => "z",
        "interviewer_notes" => "notes",
        "recommended_action" => nil
      }
    }

    res1 = handler.call(step)
    assert res1["feedback_id"].present?

    res2 = handler.call(step)
    assert_equal "already_exists", res2["status"]
    assert_equal res1["feedback_id"], res2["feedback_id"]
  end

  test "CreateOpportunity is idempotent for the same synced_email" do
    email = create(:synced_email, :processed)
    handler = Signals::Decisioning::Execution::Handlers::CreateOpportunity.new(email)

    step = {
      "step_id" => "create_opportunity",
      "action" => "create_opportunity",
      "target" => {},
      "params" => {
        "company_name" => "Acme",
        "job_title" => "Senior Engineer",
        "job_url" => "https://boards.greenhouse.io/acme/jobs/123",
        "recruiter_name" => "Jane",
        "recruiter_email" => "jane@acme.com",
        "extracted_links" => [ { "url" => "https://boards.greenhouse.io/acme/jobs/123", "type" => "job_posting", "description" => "Job posting" } ],
        "source" => { "synced_email_id" => email.id }
      }
    }

    res1 = handler.call(step)
    assert res1["opportunity_id"].present?

    res2 = handler.call(step)
    assert_equal "already_exists", res2["status"]
    assert_equal res1["opportunity_id"], res2["opportunity_id"]
  end
end
