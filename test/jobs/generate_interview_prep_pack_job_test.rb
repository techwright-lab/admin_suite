# frozen_string_literal: true

require "test_helper"

class GenerateInterviewPrepPackJobTest < ActiveJob::TestCase
  def with_new_stub(klass, instance)
    original = klass.method(:new)
    klass.define_singleton_method(:new) { |_args = nil, **_kwargs| instance }
    yield
  ensure
    klass.define_singleton_method(:new) { |*args, **kwargs, &blk| original.call(*args, **kwargs, &blk) }
  end

  test "does nothing when not entitled" do
    user = create(:user)
    create(:billing_plan, :free)
    application = create(:interview_application, user: user)

    assert_no_difference -> { Billing::UsageCounter.count } do
      GenerateInterviewPrepPackJob.perform_now(application, user: user)
    end
  end

  test "increments usage counter once and generates artifacts when entitled" do
    user = create(:user)
    create(:billing_plan, :free)
    application = create(:interview_application, user: user)

    pro_plan = create(:billing_plan, :pro)
    access = create(:billing_feature, key: "interview_prepare_access", kind: "boolean")
    quota = create(:billing_feature, :quota, key: "interview_prepare_refreshes", unit: "refreshes")
    create(:billing_plan_entitlement, plan: pro_plan, feature: access, enabled: true)
    create(:billing_plan_entitlement, plan: pro_plan, feature: quota, enabled: true, limit: 10)
    create(:billing_subscription, user: user, plan: pro_plan, status: "active", current_period_ends_at: 1.month.from_now)

    # Avoid hitting LLM providers in tests: override generator constructors.
    generator = Struct.new(:call).new(true)
    with_new_stub(InterviewPrep::GenerateMatchAnalysisService, generator) do
      with_new_stub(InterviewPrep::GenerateFocusAreasService, generator) do
        with_new_stub(InterviewPrep::GenerateQuestionFramingService, generator) do
          with_new_stub(InterviewPrep::GenerateStrengthPositioningService, generator) do
            assert_difference -> { Billing::UsageCounter.count }, +1 do
              GenerateInterviewPrepPackJob.perform_now(application, user: user)
            end
          end
        end
      end
    end

    period_start = Time.current.beginning_of_month
    counter = Billing::UsageCounter.find_by(user: user, feature_key: "interview_prepare_refreshes", period_starts_at: period_start)
    assert_equal 1, counter.used
  end

  test "respects monthly quota and does not increment when exhausted" do
    user = create(:user)
    create(:billing_plan, :free)
    application = create(:interview_application, user: user)

    pro_plan = create(:billing_plan, :pro)
    access = create(:billing_feature, key: "interview_prepare_access", kind: "boolean")
    quota = create(:billing_feature, :quota, key: "interview_prepare_refreshes", unit: "refreshes")
    create(:billing_plan_entitlement, plan: pro_plan, feature: access, enabled: true)
    create(:billing_plan_entitlement, plan: pro_plan, feature: quota, enabled: true, limit: 1)
    create(:billing_subscription, user: user, plan: pro_plan, status: "active", current_period_ends_at: 1.month.from_now)

    period_start = Time.current.beginning_of_month
    period_end = period_start + 1.month
    Billing::UsageCounter.increment!(user: user, feature_key: "interview_prepare_refreshes", period_starts_at: period_start, period_ends_at: period_end, delta: 1)

    assert_no_difference -> { Billing::UsageCounter.where(user: user, feature_key: "interview_prepare_refreshes", period_starts_at: period_start).pluck(:used).first.to_i } do
      GenerateInterviewPrepPackJob.perform_now(application, user: user)
    end
  end
end
