# frozen_string_literal: true

require "test_helper"

class Signals::StateTransitionPlannerTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @company = create(:company)
    @job_role = create(:job_role)
    @connected_account = create(:connected_account, user: @user)
    @application = create(:interview_application, user: @user, company: @company, job_role: @job_role)
  end

  test "plans rejection actions" do
    email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    actions = plan_for(email)

    assert_action(actions, :run_status_processor)
    assert_action(actions, :mark_latest_round_failed)
  end

  test "plans offer actions" do
    email = create(:synced_email, :offer,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    actions = plan_for(email)

    assert_action(actions, :run_status_processor)
  end

  test "plans round feedback actions" do
    email = create(:synced_email, :round_feedback,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    actions = plan_for(email)

    assert_action(actions, :run_round_feedback_processor)
    assert_action(actions, :sync_application_from_round_result)
  end

  test "plans scheduling actions" do
    email = create(:synced_email, :scheduling,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    actions = plan_for(email)

    assert_action(actions, :run_interview_round_processor)
    assert_action(actions, :sync_pipeline_from_round_stage)
  end

  test "plans application confirmation actions" do
    email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application,
      email_type: "application_confirmation"
    )

    actions = plan_for(email)

    assert_action(actions, :set_pipeline_stage)
  end

  private

  def plan_for(email)
    context = Signals::StateContext.new(email)
    Signals::StateTransitionPlanner.new(context).plan
  end

  def assert_action(actions, action_type)
    assert actions.any? { |action| action[:type] == action_type }, "Expected action #{action_type}"
  end
end
