# frozen_string_literal: true

require "test_helper"

class InterviewApplicationPrepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as(@user)
    create(:billing_plan, :free)
    @application = create(:interview_application, user: @user)
  end

  test "refresh redirects with upgrade message when not entitled" do
    assert_no_enqueued_jobs only: GenerateInterviewPrepPackJob do
      post refresh_interview_application_prep_path(@application)
    end

    assert_redirected_to interview_application_path(@application, tab: "prepare")
    assert_equal "Upgrade to unlock full Prepare", flash[:alert]
  end

  test "refresh enqueues job when entitled and refreshes remaining" do
    pro_plan = create(:billing_plan, :pro)
    access = create(:billing_feature, key: "interview_prepare_access", kind: "boolean")
    quota = create(:billing_feature, :quota, key: "interview_prepare_refreshes", unit: "refreshes")
    create(:billing_plan_entitlement, plan: pro_plan, feature: access, enabled: true)
    create(:billing_plan_entitlement, plan: pro_plan, feature: quota, enabled: true, limit: 10)
    create(:billing_subscription, user: @user, plan: pro_plan, status: "active", current_period_ends_at: 1.month.from_now)

    assert_enqueued_with(job: GenerateInterviewPrepPackJob) do
      post refresh_interview_application_prep_path(@application)
    end

    assert_redirected_to interview_application_path(@application, tab: "prepare")
    assert_equal "Generating prep…", flash[:notice]
  end
end
