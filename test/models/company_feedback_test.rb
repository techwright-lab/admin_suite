# frozen_string_literal: true

require "test_helper"

class CompanyFeedbackTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @company = create(:company)
    @job_role = create(:job_role)
    @application = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    @feedback = build(:company_feedback, interview_application: @application)
  end

  # Validations
  test "valid feedback" do
    assert @feedback.valid?
  end

  test "requires interview_application" do
    @feedback.interview_application = nil
    assert_not @feedback.valid?
    assert_includes @feedback.errors[:interview_application], "can't be blank"
  end

  # Associations
  test "belongs to interview_application" do
    assert_respond_to @feedback, :interview_application
    assert_instance_of InterviewApplication, @feedback.interview_application
  end

  # Scopes
  test "recent scope orders by received_at desc, then created_at desc" do
    feedback1 = create(:company_feedback, interview_application: @application, received_at: 2.days.ago)
    feedback2 = create(:company_feedback, interview_application: create(:interview_application, user: @user, company: @company, job_role: @job_role), received_at: 1.day.ago)
    
    assert_equal [feedback2, feedback1], CompanyFeedback.recent.to_a
  end

  test "with_rejection scope returns only feedback with rejection_reason" do
    with_rejection = create(:company_feedback, :with_rejection, interview_application: @application)
    without_rejection = create(:company_feedback, interview_application: create(:interview_application, user: @user, company: @company, job_role: @job_role))
    
    assert_includes CompanyFeedback.with_rejection, with_rejection
    assert_not_includes CompanyFeedback.with_rejection, without_rejection
  end

  # Helper methods
  test "#rejection? returns true when rejection_reason present" do
    @feedback.rejection_reason = "Not enough experience"
    assert @feedback.rejection?
  end

  test "#rejection? returns false when rejection_reason nil" do
    @feedback.rejection_reason = nil
    assert_not @feedback.rejection?
  end

  test "#received? returns true when received_at present" do
    @feedback.received_at = 1.day.ago
    assert @feedback.received?
  end

  test "#received? returns false when received_at nil" do
    @feedback.received_at = nil
    assert_not @feedback.received?
  end

  test "#summary returns feedback_text when present" do
    @feedback.feedback_text = "Great interview performance"
    assert_equal "Great interview performance", @feedback.summary
  end

  test "#summary returns default message when feedback_text nil" do
    @feedback.feedback_text = nil
    assert_equal "No feedback yet", @feedback.summary
  end

  test "#has_next_steps? returns true when next_steps present" do
    @feedback.next_steps = "Schedule follow-up"
    assert @feedback.has_next_steps?
  end

  test "#has_next_steps? returns false when next_steps nil" do
    @feedback.next_steps = nil
    assert_not @feedback.has_next_steps?
  end

  test "#sentiment returns negative for rejection" do
    @feedback.rejection_reason = "Not a good fit"
    assert_equal "negative", @feedback.sentiment
  end

  test "#sentiment returns positive for next_steps" do
    @feedback.next_steps = "Moving forward"
    @feedback.rejection_reason = nil
    assert_equal "positive", @feedback.sentiment
  end

  test "#sentiment returns neutral otherwise" do
    @feedback.rejection_reason = nil
    @feedback.next_steps = nil
    assert_equal "neutral", @feedback.sentiment
  end
end
