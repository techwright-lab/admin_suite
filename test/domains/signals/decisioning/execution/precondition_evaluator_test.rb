# frozen_string_literal: true

require "test_helper"

class SignalsDecisioningExecutionPreconditionEvaluatorTest < ActiveSupport::TestCase
  test "unknown predicates fail closed" do
    email = create(:synced_email)
    res = Signals::Decisioning::Execution::PreconditionEvaluator.evaluate_all(
      [ "some.unknown.predicate == true" ],
      synced_email: email,
      step: { "target" => {} }
    )

    assert_equal false, res[:ok]
    assert_includes res[:unknown], "some.unknown.predicate == true"
  end

  test "match.matched == true evaluates from synced_email" do
    email = create(:synced_email, interview_application: nil)
    res = Signals::Decisioning::Execution::PreconditionEvaluator.evaluate_all(
      [ "match.matched == true" ],
      synced_email: email,
      step: { "target" => {} }
    )
    assert_equal false, res[:ok]

    app = create(:interview_application, user: email.user)
    email.update!(interview_application: app)
    res2 = Signals::Decisioning::Execution::PreconditionEvaluator.evaluate_all(
      [ "match.matched == true" ],
      synced_email: email.reload,
      step: { "target" => {} }
    )
    assert_equal true, res2[:ok]
  end
end
