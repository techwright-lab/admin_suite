# frozen_string_literal: true

require "test_helper"

class SignalsDecisioningPlannerContractTest < ActiveSupport::TestCase
  DECISION_PLAN_SCHEMA_ID = "gleania://signals/contracts/schemas/decision_plan.schema.json"

  test "planner emits schema-valid and semantically-valid plans for core fixtures" do
    validator = Signals::Contracts::Validators::JsonSchemaValidator.new(schema_id: DECISION_PLAN_SCHEMA_ID)

    fixtures = %w[
      scheduling_confirmed
      round_feedback_passed
      rejection
      offer
      recruiter_outreach
    ]

    fixtures.each do |name|
      input = JSON.parse(File.read(Rails.root.join("app/domains/signals/contracts/examples/decision_input/#{name}.json")))
      plan = Signals::Decisioning::Planner.new(input).plan

      schema_errors = validator.errors_for(plan)
      assert schema_errors.empty?, "Schema errors for #{name}: #{schema_errors.inspect}"

      semantic_errors = Signals::Decisioning::SemanticValidator.new(input, plan).errors
      assert semantic_errors.empty?, "Semantic errors for #{name}: #{semantic_errors.inspect}\nPlan: #{plan.inspect}"
    end
  end
end
