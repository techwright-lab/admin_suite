# frozen_string_literal: true

require "test_helper"

class SignalsContractsValidationTest < ActiveSupport::TestCase
  DECISION_INPUT_SCHEMA_ID = "gleania://signals/contracts/schemas/decision_input.schema.json"
  DECISION_PLAN_SCHEMA_ID = "gleania://signals/contracts/schemas/decision_plan.schema.json"

  test "decision input examples validate against schema" do
    validator = Signals::Contracts::Validators::JsonSchemaValidator.new(schema_id: DECISION_INPUT_SCHEMA_ID)
    example_paths = Dir[Rails.root.join("app/domains/signals/contracts/examples/decision_input/*.json")].sort
    assert example_paths.any?, "Expected decision input examples to exist"

    example_paths.each do |path|
      data = JSON.parse(File.read(path))
      errors = validator.errors_for(data)
      assert errors.empty?, "Schema errors for #{path}:\n#{errors.inspect}"
    end
  end

  test "decision plan examples validate against schema" do
    validator = Signals::Contracts::Validators::JsonSchemaValidator.new(schema_id: DECISION_PLAN_SCHEMA_ID)
    example_paths = Dir[Rails.root.join("app/domains/signals/contracts/examples/decision_plan/*.json")].sort
    assert example_paths.any?, "Expected decision plan examples to exist"

    example_paths.each do |path|
      data = JSON.parse(File.read(path))
      errors = validator.errors_for(data)
      assert errors.empty?, "Schema errors for #{path}:\n#{errors.inspect}"
    end
  end
end
