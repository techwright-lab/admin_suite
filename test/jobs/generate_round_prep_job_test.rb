# frozen_string_literal: true

require "test_helper"

class GenerateRoundPrepJobTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @company = create(:company)
    @job_role = create(:job_role)
    @application = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    @round = create(:interview_round, interview_application: @application)

    # Create billing features
    @access_feature = Billing::Feature.find_or_create_by!(key: "round_prep_access") do |f|
      f.name = "Round prep access"
      f.kind = "boolean"
    end
    @quota_feature = Billing::Feature.find_or_create_by!(key: "round_prep_generations") do |f|
      f.name = "Round prep generations"
      f.kind = "quota"
      f.unit = "generations"
    end

    # Create free plan with no access
    @free_plan = Billing::Plan.find_or_create_by!(key: "free") do |p|
      p.name = "Free"
      p.plan_type = "free"
    end
    Billing::PlanEntitlement.find_or_create_by!(plan: @free_plan, feature: @access_feature) do |pe|
      pe.enabled = false
    end
    Billing::PlanEntitlement.find_or_create_by!(plan: @free_plan, feature: @quota_feature) do |pe|
      pe.enabled = true
      pe.limit = 0
    end
  end

  test "does not generate when user lacks round_prep_access" do
    # User is on free plan (no access)
    assert_no_difference -> { InterviewRoundPrepArtifact.count } do
      GenerateRoundPrepJob.perform_now(@round)
    end
  end

  test "does not generate when quota is exhausted" do
    # Create pro plan with access
    pro_plan = Billing::Plan.find_or_create_by!(key: "pro_test") do |p|
      p.name = "Pro Test"
      p.plan_type = "recurring"
      p.interval = "month"
      p.amount_cents = 1200
      p.currency = "eur"
    end
    Billing::PlanEntitlement.find_or_create_by!(plan: pro_plan, feature: @access_feature) do |pe|
      pe.enabled = true
    end
    Billing::PlanEntitlement.find_or_create_by!(plan: pro_plan, feature: @quota_feature) do |pe|
      pe.enabled = true
      pe.limit = 1
    end

    # Subscribe user to pro
    create(:billing_subscription, user: @user, plan: pro_plan)

    # Use up the quota
    period_start = Time.current.beginning_of_month
    period_end = period_start + 1.month
    Billing::UsageCounter.increment!(
      user: @user,
      feature_key: "round_prep_generations",
      period_starts_at: period_start,
      period_ends_at: period_end,
      delta: 1
    )

    # Should not generate (quota exhausted)
    assert_no_difference -> { InterviewRoundPrepArtifact.count } do
      GenerateRoundPrepJob.perform_now(@round)
    end
  end

  test "increments usage counter on generation" do
    # Create pro plan with access and quota
    pro_plan = Billing::Plan.find_or_create_by!(key: "pro_gen_test") do |p|
      p.name = "Pro Gen Test"
      p.plan_type = "recurring"
      p.interval = "month"
      p.amount_cents = 1200
      p.currency = "eur"
    end
    Billing::PlanEntitlement.find_or_create_by!(plan: pro_plan, feature: @access_feature) do |pe|
      pe.enabled = true
    end
    Billing::PlanEntitlement.find_or_create_by!(plan: pro_plan, feature: @quota_feature) do |pe|
      pe.enabled = true
      pe.limit = 10
    end

    # Subscribe user to pro
    create(:billing_subscription, user: @user, plan: pro_plan)

    period_start = Time.current.beginning_of_month

    # Stub the service call to avoid LLM
    InterviewRoundPrep::GenerateService.define_method(:call) do
      InterviewRoundPrepArtifact.find_or_initialize_for(interview_round: @round, kind: :comprehensive).tap do |a|
        a.status = :completed
        a.save! if a.new_record?
      end
    end

    assert_difference -> { Billing::UsageCounter.where(user: @user, feature_key: "round_prep_generations", period_starts_at: period_start).sum(:used) }, 1 do
      GenerateRoundPrepJob.perform_now(@round)
    end
  ensure
    # Restore original method
    InterviewRoundPrep::GenerateService.remove_method(:call) if InterviewRoundPrep::GenerateService.method_defined?(:call)
  end

  test "generates prep for user with entitlement grant (trial)" do
    # Create entitlement grant (trial)
    Billing::EntitlementGrant.create!(
      user: @user,
      source: "trial",
      reason: "insight_triggered",
      starts_at: 1.day.ago,
      expires_at: 2.days.from_now,
      entitlements: {
        "round_prep_access" => { "enabled" => true },
        "round_prep_generations" => { "enabled" => true, "limit" => 10 }
      }
    )

    period_start = Time.current.beginning_of_month

    # Stub the service call to avoid LLM
    InterviewRoundPrep::GenerateService.define_method(:call) do
      InterviewRoundPrepArtifact.find_or_initialize_for(interview_round: @round, kind: :comprehensive).tap do |a|
        a.status = :completed
        a.save! if a.new_record?
      end
    end

    assert_difference -> { Billing::UsageCounter.where(user: @user, feature_key: "round_prep_generations", period_starts_at: period_start).sum(:used) }, 1 do
      GenerateRoundPrepJob.perform_now(@round)
    end
  ensure
    # Restore original method
    InterviewRoundPrep::GenerateService.remove_method(:call) if InterviewRoundPrep::GenerateService.method_defined?(:call)
  end
end
