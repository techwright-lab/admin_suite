# frozen_string_literal: true

require "test_helper"

class InterviewRoundPrep::HistoricalAnalyzerServiceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @company = create(:company)
    @job_role = create(:job_role)
    @category = Category.find_or_create_by!(kind: :job_role, name: "Engineering")

    @round_type = InterviewRoundType.find_or_create_by!(slug: "coding_has") do |rt|
      rt.name = "Coding Interview"
      rt.category = @category
    end
  end

  test "returns empty analysis when no historical rounds" do
    service = InterviewRoundPrep::HistoricalAnalyzerService.new(user: @user, round_type: @round_type)
    result = service.analyze

    assert_equal 0, result[:total_rounds]
    assert_equal 0, result[:completed_rounds]
    assert result[:note].present?
  end

  test "calculates total and completed rounds" do
    application = create(:interview_application, user: @user, company: @company, job_role: @job_role)

    # Create some completed rounds
    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 1.day.ago, result: :passed)
    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 2.days.ago, result: :passed)
    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: nil) # not completed

    service = InterviewRoundPrep::HistoricalAnalyzerService.new(user: @user, round_type: @round_type)
    result = service.analyze

    assert_equal 3, result[:total_rounds]
    assert_equal 2, result[:completed_rounds]
  end

  test "calculates pass rate" do
    application = create(:interview_application, user: @user, company: @company, job_role: @job_role)

    # 3 passed, 1 failed = 75% pass rate
    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 1.day.ago, result: :passed)
    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 2.days.ago, result: :passed)
    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 3.days.ago, result: :passed)
    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 4.days.ago, result: :failed)

    service = InterviewRoundPrep::HistoricalAnalyzerService.new(user: @user, round_type: @round_type)
    result = service.analyze

    assert_equal 75.0, result[:pass_rate]
  end

  test "calculates average duration" do
    application = create(:interview_application, user: @user, company: @company, job_role: @job_role)

    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 1.day.ago, duration_minutes: 45)
    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 2.days.ago, duration_minutes: 60)
    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 3.days.ago, duration_minutes: 75)

    service = InterviewRoundPrep::HistoricalAnalyzerService.new(user: @user, round_type: @round_type)
    result = service.analyze

    assert_equal 60, result[:average_duration_minutes]
  end

  test "only analyzes rounds matching the round_type" do
    application = create(:interview_application, user: @user, company: @company, job_role: @job_role)

    other_type = InterviewRoundType.create!(name: "System Design", slug: "system_design")

    # Create rounds of different types
    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 1.day.ago)
    create(:interview_round, interview_application: application, interview_round_type: other_type, completed_at: 2.days.ago)
    create(:interview_round, interview_application: application, interview_round_type: nil, completed_at: 3.days.ago)

    service = InterviewRoundPrep::HistoricalAnalyzerService.new(user: @user, round_type: @round_type)
    result = service.analyze

    assert_equal 1, result[:total_rounds]
  end

  test "analyzes all rounds when round_type is nil" do
    application = create(:interview_application, user: @user, company: @company, job_role: @job_role)

    other_type = InterviewRoundType.create!(name: "System Design", slug: "system_design")

    create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: 1.day.ago)
    create(:interview_round, interview_application: application, interview_round_type: other_type, completed_at: 2.days.ago)
    create(:interview_round, interview_application: application, interview_round_type: nil, completed_at: 3.days.ago)

    service = InterviewRoundPrep::HistoricalAnalyzerService.new(user: @user, round_type: nil)
    result = service.analyze

    assert_equal 3, result[:total_rounds]
  end

  test "determines performance trend from recent results" do
    application = create(:interview_application, user: @user, company: @company, job_role: @job_role)

    # 4 passed, 1 failed in recent = strong trend
    5.times do |i|
      result = i == 0 ? :failed : :passed
      create(:interview_round, interview_application: application, interview_round_type: @round_type, completed_at: (i + 1).days.ago, result: result)
    end

    service = InterviewRoundPrep::HistoricalAnalyzerService.new(user: @user, round_type: @round_type)
    result = service.analyze

    assert_equal "strong", result[:performance_trend]
  end
end
