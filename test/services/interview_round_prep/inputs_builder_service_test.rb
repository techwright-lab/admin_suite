# frozen_string_literal: true

require "test_helper"

class InterviewRoundPrep::InputsBuilderServiceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user, name: "Test User", years_of_experience: 5)
    @company = create(:company, name: "Tech Corp")
    @category = Category.find_or_create_by!(kind: :job_role, name: "Engineering")
    @job_role = create(:job_role, title: "Software Engineer", category: @category)
    @application = create(:interview_application, user: @user, company: @company, job_role: @job_role)

    @round_type = InterviewRoundType.find_or_create_by!(slug: "coding_ibs") do |rt|
      rt.name = "Coding Interview"
      rt.category = @category
    end

    @round = create(:interview_round,
      interview_application: @application,
      stage: :technical,
      interview_round_type: @round_type,
      scheduled_at: 2.days.from_now,
      duration_minutes: 60
    )
  end

  test "build returns all expected keys" do
    service = InterviewRoundPrep::InputsBuilderService.new(interview_round: @round)
    result = service.build

    assert_includes result.keys, :algorithm_version
    assert_includes result.keys, :round_context
    assert_includes result.keys, :job_context
    assert_includes result.keys, :candidate_profile
    assert_includes result.keys, :historical_performance
    assert_includes result.keys, :company_patterns
  end

  test "round_context includes round details" do
    service = InterviewRoundPrep::InputsBuilderService.new(interview_round: @round)
    result = service.build

    round_context = result[:round_context]
    assert_equal @round.id, round_context[:id]
    assert_equal "technical", round_context[:stage]
    assert_equal 60, round_context[:duration_minutes]
    assert round_context[:round_type].present?
    assert_equal "Coding Interview", round_context[:round_type][:name]
    assert_equal "coding_ibs", round_context[:round_type][:slug]
  end

  test "job_context includes company and role info" do
    service = InterviewRoundPrep::InputsBuilderService.new(interview_round: @round)
    result = service.build

    job_context = result[:job_context]
    assert_equal "Tech Corp", job_context[:company]
    assert_equal "Software Engineer", job_context[:role]
    assert_equal "Engineering", job_context[:department]
  end

  test "candidate_profile includes user info" do
    service = InterviewRoundPrep::InputsBuilderService.new(interview_round: @round)
    result = service.build

    candidate = result[:candidate_profile]
    assert_equal "Test User", candidate[:name]
    assert_equal 5, candidate[:years_of_experience]
  end

  test "digest_for returns consistent digest for same inputs" do
    service = InterviewRoundPrep::InputsBuilderService.new(interview_round: @round)

    digest1 = service.digest_for(:comprehensive)
    digest2 = service.digest_for(:comprehensive)

    assert_equal digest1, digest2
    assert_match(/\A[a-f0-9]{64}\z/, digest1) # SHA256 hex
  end

  test "digest_for returns different digest for different kinds" do
    service = InterviewRoundPrep::InputsBuilderService.new(interview_round: @round)

    digest1 = service.digest_for(:comprehensive)
    digest2 = service.digest_for(:questions)

    assert_not_equal digest1, digest2
  end

  test "handles round without round_type" do
    round_without_type = create(:interview_round,
      interview_application: @application,
      stage: :screening,
      interview_round_type: nil
    )

    service = InterviewRoundPrep::InputsBuilderService.new(interview_round: round_without_type)
    result = service.build

    assert_nil result[:round_context][:round_type]
  end
end
