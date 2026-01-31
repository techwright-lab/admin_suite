# frozen_string_literal: true

require "test_helper"

class SignalsDecisioningExecutionRunnerTest < ActiveSupport::TestCase
  setup do
    Setting.set(name: "signals_decision_execution_enabled", value: true)
    Setting.set(name: "signals_email_facts_extraction_enabled", value: true)
  end

  test "execution creates a round for a schema-valid scheduling facts payload" do
    fixture = JSON.parse(File.read(Rails.root.join("app/domains/signals/contracts/examples/decision_input/scheduling_confirmed.json")))
    facts = fixture.fetch("facts")
    body_text = fixture.dig("event", "body", "text")

    app = create(:interview_application)
    email = create(
      :synced_email,
      status: :processed,
      interview_application: app,
      subject: fixture.dig("event", "subject"),
      from_email: fixture.dig("event", "from", "email"),
      from_name: fixture.dig("event", "from", "name"),
      body_preview: body_text,
      email_date: Time.iso8601(fixture.dig("event", "email_date"))
    )

    email.update!(
      extracted_data: (email.extracted_data.is_a?(Hash) ? email.extracted_data : {}).merge(
        Signals::Facts::EmailFactsExtractor::FACTS_KEY => facts,
        Signals::Facts::EmailFactsExtractor::FACTS_META_KEY => { "status" => "ok", "generated_at" => Time.current.iso8601 }
      )
    )

    assert_difference -> { InterviewRound.count }, +1 do
      assert Signals::Decisioning::ExecutionRunner.new(email).call
    end

    app.reload
    round = app.interview_rounds.ordered.last
    assert_equal "screening", round.stage
    assert_equal Time.iso8601("2026-01-28T22:00:00Z"), round.scheduled_at
    assert_equal 30, round.duration_minutes
    assert_equal "Jordan Lee", round.interviewer_name
    assert_equal "https://zoom.us/j/123456789", round.video_link

    email.reload
    assert_equal "executed", email.extracted_data.dig("decision_execution_v1", "status")
  end

  test "execution fails closed when planner produces evidence not present in the email body" do
    fixture = JSON.parse(File.read(Rails.root.join("app/domains/signals/contracts/examples/decision_input/scheduling_confirmed.json")))
    facts = fixture.fetch("facts")
    body_text = fixture.dig("event", "body", "text")

    app = create(:interview_application)
    email = create(
      :synced_email,
      status: :processed,
      interview_application: app,
      subject: fixture.dig("event", "subject"),
      from_email: fixture.dig("event", "from", "email"),
      from_name: fixture.dig("event", "from", "name"),
      body_preview: body_text,
      email_date: Time.iso8601(fixture.dig("event", "email_date"))
    )

    email.update!(
      extracted_data: (email.extracted_data.is_a?(Hash) ? email.extracted_data : {}).merge(
        Signals::Facts::EmailFactsExtractor::FACTS_KEY => facts,
        Signals::Facts::EmailFactsExtractor::FACTS_META_KEY => { "status" => "ok", "generated_at" => Time.current.iso8601 }
      )
    )

    original_plan = Signals::Decisioning::Planner.new(
      Signals::Decisioning::DecisionInputBuilder.new(email).build(facts: facts)
    ).plan
    tampered_plan = Marshal.load(Marshal.dump(original_plan))
    tampered_plan.fetch("plan").first["evidence"] = [ "NOT PRESENT IN BODY" ]

    assert_no_difference -> { InterviewRound.count } do
      fake_planner = Struct.new(:plan)
      original_new = Signals::Decisioning::Planner.singleton_class.instance_method(:new)
      Signals::Decisioning::Planner.singleton_class.define_method(:new) { |_input| fake_planner.new(tampered_plan) }

      begin
        refute Signals::Decisioning::ExecutionRunner.new(email).call
      ensure
        Signals::Decisioning::Planner.singleton_class.define_method(:new, original_new)
      end
    end

    email.reload
    assert_equal "semantic_invalid", email.extracted_data.dig("decision_execution_v1", "status")
  end
end
