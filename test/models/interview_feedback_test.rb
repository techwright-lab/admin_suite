# frozen_string_literal: true

require "test_helper"

class InterviewFeedbackTest < ActiveSupport::TestCase
  def setup
    @feedback = build(:interview_feedback)
  end

  test "valid feedback" do
    assert @feedback.valid?
  end

  test "requires interview_round" do
    @feedback.interview_round = nil
    assert_not @feedback.valid?
    assert_includes @feedback.errors[:interview_round], "can't be blank"
  end

  test "belongs to interview_round" do
    feedback = create(:interview_feedback)
    assert_instance_of InterviewRound, feedback.interview_round
  end

  test "#tag_list returns tags as array" do
    @feedback.tags = ["Ruby", "Rails", "PostgreSQL"]
    assert_equal ["Ruby", "Rails", "PostgreSQL"], @feedback.tag_list
  end

  test "#tag_list returns empty array when tags is nil" do
    @feedback.tags = nil
    assert_equal [], @feedback.tag_list
  end

  test "#tag_list= sets tags from array" do
    @feedback.tag_list = ["Ruby", "Rails"]
    assert_equal ["Ruby", "Rails"], @feedback.tags
  end

  test "#tag_list= sets tags from comma-separated string" do
    @feedback.tag_list = "Ruby, Rails, PostgreSQL"
    assert_equal ["Ruby", "Rails", "PostgreSQL"], @feedback.tags
  end

  test "#tag_list= removes blank values" do
    @feedback.tag_list = "Ruby, , Rails,  , PostgreSQL"
    assert_equal ["Ruby", "Rails", "PostgreSQL"], @feedback.tags
  end

  test "#has_ai_summary? returns true when ai_summary present" do
    @feedback.ai_summary = "Good performance overall"
    assert @feedback.has_ai_summary?
  end

  test "#has_ai_summary? returns false when ai_summary blank" do
    @feedback.ai_summary = nil
    assert_not @feedback.has_ai_summary?
  end

  test "#summary_preview returns truncated went_well" do
    @feedback.went_well = "A" * 150
    preview = @feedback.summary_preview
    assert_equal 100, preview.length
    assert preview.ends_with?("...")
  end

  test "#summary_preview returns default when went_well blank" do
    @feedback.went_well = nil
    assert_equal "No feedback yet", @feedback.summary_preview
  end

  test "recent scope orders by created_at desc" do
    old_feedback = create(:interview_feedback, created_at: 2.days.ago)
    new_feedback = create(:interview_feedback, created_at: 1.day.ago)
    
    feedbacks = InterviewFeedback.recent
    assert_equal new_feedback.id, feedbacks.first.id
    assert_equal old_feedback.id, feedbacks.last.id
  end

  test "with_recommendations scope filters feedbacks with recommended_action" do
    with_rec = create(:interview_feedback, recommended_action: "Practice more")
    without_rec = create(:interview_feedback, recommended_action: nil)
    
    feedbacks = InterviewFeedback.with_recommendations
    assert_includes feedbacks, with_rec
    assert_not_includes feedbacks, without_rec
  end

  test "positive trait creates optimistic feedback" do
    feedback = build(:interview_feedback, :positive)
    assert feedback.went_well.present?
    assert feedback.to_improve.nil?
    assert_match(/outstanding/i, feedback.ai_summary)
  end

  test "needs_improvement trait creates constructive feedback" do
    feedback = build(:interview_feedback, :needs_improvement)
    assert feedback.went_well.present?
    assert feedback.to_improve.present?
    assert feedback.recommended_action.present?
  end

  test "minimal trait creates sparse feedback" do
    feedback = build(:interview_feedback, :minimal)
    assert feedback.went_well.present?
    assert feedback.to_improve.nil?
    assert feedback.tags.empty?
    assert feedback.ai_summary.nil?
  end
end

