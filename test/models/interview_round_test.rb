# frozen_string_literal: true

require "test_helper"

class InterviewRoundTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @company = create(:company)
    @job_role = create(:job_role)
    @application = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    @round = build(:interview_round, interview_application: @application)
  end

  # Validations
  test "valid round" do
    assert @round.valid?
  end

  test "requires interview_application" do
    @round.interview_application = nil
    assert_not @round.valid?
    assert_includes @round.errors[:interview_application], "can't be blank"
  end

  test "requires stage" do
    @round.stage = nil
    assert_not @round.valid?
    assert_includes @round.errors[:stage], "can't be blank"
  end

  # Enums
  test "has stage enum" do
    assert_respond_to @round, :stage
    assert_respond_to @round, :screening?
    assert_respond_to @round, :technical?
    assert_respond_to @round, :hiring_manager?
    assert_respond_to @round, :culture_fit?
  end

  test "has result enum" do
    assert_respond_to @round, :result
    assert_respond_to @round, :pending?
    assert_respond_to @round, :passed?
    assert_respond_to @round, :failed?
    assert_respond_to @round, :waitlisted?
  end

  test "defaults to screening stage" do
    round = InterviewRound.create!(interview_application: @application)
    assert round.screening?
  end

  test "defaults to pending result" do
    round = InterviewRound.create!(interview_application: @application)
    assert round.pending?
  end

  # Associations
  test "belongs to interview_application" do
    assert_respond_to @round, :interview_application
    assert_instance_of InterviewApplication, @round.interview_application
  end

  test "has one interview_feedback" do
    round = create(:interview_round, interview_application: @application)
    feedback = create(:interview_feedback, interview_round: round, self_reflection: "Test")

    assert_not_nil feedback
    assert_equal round.id, feedback.interview_round_id
  end

  # Scopes
  test "by_stage scope filters by stage" do
    screening = create(:interview_round, :screening, interview_application: @application)
    technical = create(:interview_round, :technical, interview_application: @application)
    
    assert_includes InterviewRound.by_stage(:screening), screening
    assert_not_includes InterviewRound.by_stage(:screening), technical
  end

  test "completed scope returns only completed rounds" do
    completed = create(:interview_round, :completed, interview_application: @application)
    upcoming = create(:interview_round, :upcoming, interview_application: @application)
    
    assert_includes InterviewRound.completed, completed
    assert_not_includes InterviewRound.completed, upcoming
  end

  test "upcoming scope returns only upcoming rounds" do
    completed = create(:interview_round, :completed, interview_application: @application)
    upcoming = create(:interview_round, :upcoming, interview_application: @application)
    
    assert_includes InterviewRound.upcoming, upcoming
    assert_not_includes InterviewRound.upcoming, completed
  end

  test "ordered scope orders by position, scheduled_at, created_at" do
    round3 = create(:interview_round, interview_application: @application, position: 3)
    round1 = create(:interview_round, interview_application: @application, position: 1)
    round2 = create(:interview_round, interview_application: @application, position: 2)
    
    assert_equal [round1, round2, round3], InterviewRound.ordered.to_a
  end

  # Helper methods
  test "#stage_display_name returns formatted stage name" do
    @round.stage = :screening
    assert_equal "Phone Screen", @round.stage_display_name
    
    @round.stage = :technical
    assert_equal "Phone Screen", @round.stage_display_name
    
    @round.stage = :hiring_manager
    assert_equal "Phone Screen", @round.stage_display_name
  end

  test "#completed? returns true when completed_at is set" do
    @round.completed_at = 1.day.ago
    assert @round.completed?
  end

  test "#completed? returns false when completed_at is nil" do
    @round.completed_at = nil
    assert_not @round.completed?
  end

  test "#upcoming? returns true when scheduled in future and not completed" do
    @round.scheduled_at = 1.day.from_now
    @round.completed_at = nil
    assert @round.upcoming?
  end

  test "#upcoming? returns false when completed" do
    @round.scheduled_at = 1.day.from_now
    @round.completed_at = 1.hour.ago
    assert_not @round.upcoming?
  end

  test "#upcoming? returns false when scheduled in past" do
    @round.scheduled_at = 1.day.ago
    @round.completed_at = nil
    assert_not @round.upcoming?
  end

  test "#formatted_duration returns duration in hours and minutes" do
    @round.duration_minutes = 90
    assert_equal "1h 30m", @round.formatted_duration
    
    @round.duration_minutes = 45
    assert_equal "45m", @round.formatted_duration
    
    @round.duration_minutes = 120
    assert_equal "2h 0m", @round.formatted_duration
  end

  test "#formatted_duration returns nil when duration is nil" do
    @round.duration_minutes = nil
    assert_nil @round.formatted_duration
  end

  test "#result_badge_color returns correct color for result" do
    @round.result = :pending
    assert_equal "yellow", @round.result_badge_color
    
    @round.result = :passed
    assert_equal "green", @round.result_badge_color
    
    @round.result = :failed
    assert_equal "red", @round.result_badge_color
    
    @round.result = :waitlisted
    assert_equal "blue", @round.result_badge_color
  end

  test "#interviewer_display returns formatted interviewer info" do
    @round.interviewer_name = "Jane Smith"
    @round.interviewer_role = "Senior Engineer"
    
    assert_equal "Jane Smith (Senior Engineer)", @round.interviewer_display
  end

  test "#interviewer_display returns only name when role is nil" do
    @round.interviewer_name = "Jane Smith"
    @round.interviewer_role = nil
    
    assert_equal "Jane Smith", @round.interviewer_display
  end

  test "#interviewer_display returns nil when name is nil" do
    @round.interviewer_name = nil
    assert_nil @round.interviewer_display
  end
end
