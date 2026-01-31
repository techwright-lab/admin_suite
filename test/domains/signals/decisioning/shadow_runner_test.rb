# frozen_string_literal: true

require "test_helper"

class SignalsDecisioningShadowRunnerTest < ActiveSupport::TestCase
  test "stores decision_input_v1 and decision_plan_v1 under extracted_data without clobbering signals" do
    Setting.set(name: "signals_decision_shadow_enabled", value: true)

    application = create(:interview_application)
    email = create(:synced_email, :with_extraction, interview_application: application, status: :processed)

    assert email.extracted_data["signal_company_name"].present?
    refute email.extracted_data.key?("decision_input_v1")

    Signals::Decisioning::ShadowRunner.new(email).call
    email.reload

    assert email.extracted_data.key?("decision_input_v1")
    assert email.extracted_data.key?("decision_plan_v1")
    assert email.extracted_data.key?("decisioning_meta_v1")

    # Existing signal keys remain present
    assert_equal "Example Corp", email.extracted_data["signal_company_name"]
  end

  test "unmatched emails still produce a schema-valid DecisionInput (application null) and noop plan" do
    Setting.set(name: "signals_decision_shadow_enabled", value: true)

    email = create(:synced_email, :with_extraction, status: :processed, interview_application: nil)
    email.update!(interview_application_id: nil)

    Signals::Decisioning::ShadowRunner.new(email).call
    email.reload

    assert email.extracted_data["decision_input_v1"].is_a?(Hash)
    assert_nil email.extracted_data["decision_input_v1"]["application"]
    assert_equal false, email.extracted_data["decision_input_v1"].dig("match", "matched")

    assert_equal "noop", email.extracted_data["decision_plan_v1"]["decision"]
  end
end
