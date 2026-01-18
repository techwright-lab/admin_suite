# frozen_string_literal: true

require "test_helper"

class InterviewRoundPrep::CompanyPatternsServiceTest < ActiveSupport::TestCase
  setup do
    @company = create(:company, name: "Tech Corp")
    @job_role = create(:job_role)
    @category = Category.find_or_create_by!(kind: :job_role, name: "Engineering")

    @round_type = InterviewRoundType.find_or_create_by!(slug: "coding_cps") do |rt|
      rt.name = "Coding Interview"
      rt.category = @category
    end
  end

  test "returns empty analysis when company is nil" do
    service = InterviewRoundPrep::CompanyPatternsService.new(company: nil, round_type: @round_type)
    result = service.analyze

    assert_equal 0, result[:total_interviews]
    assert result[:note].present?
  end

  test "returns empty analysis when no company rounds exist" do
    service = InterviewRoundPrep::CompanyPatternsService.new(company: @company, round_type: @round_type)
    result = service.analyze

    assert_equal 0, result[:total_interviews]
  end

  test "includes company name in analysis" do
    user = create(:user)
    application = create(:interview_application, user: user, company: @company, job_role: @job_role)
    create(:interview_round, interview_application: application, interview_round_type: @round_type)

    service = InterviewRoundPrep::CompanyPatternsService.new(company: @company, round_type: @round_type)
    result = service.analyze

    assert_equal "Tech Corp", result[:company_name]
    assert_equal 1, result[:total_interviews]
  end

  test "calculates round type patterns" do
    user1 = create(:user)
    user2 = create(:user)

    app1 = create(:interview_application, user: user1, company: @company, job_role: @job_role)
    app2 = create(:interview_application, user: user2, company: @company, job_role: @job_role)

    # 2 passed, 1 failed = 66.7% pass rate
    create(:interview_round, interview_application: app1, interview_round_type: @round_type, completed_at: 1.day.ago, result: :passed)
    create(:interview_round, interview_application: app1, interview_round_type: @round_type, completed_at: 2.days.ago, result: :passed)
    create(:interview_round, interview_application: app2, interview_round_type: @round_type, completed_at: 3.days.ago, result: :failed)

    service = InterviewRoundPrep::CompanyPatternsService.new(company: @company, round_type: @round_type)
    result = service.analyze

    assert result[:round_type_data].present?
    assert_equal "Coding Interview", result[:round_type_data][:round_type_name]
    assert_equal 3, result[:round_type_data][:total_at_company]
    assert_in_delta 66.7, result[:round_type_data][:pass_rate], 0.1
  end

  test "calculates typical interview process" do
    user = create(:user)
    application = create(:interview_application, user: user, company: @company, job_role: @job_role)

    create(:interview_round, interview_application: application, stage: :screening, position: 1)
    create(:interview_round, interview_application: application, stage: :technical, position: 2)
    create(:interview_round, interview_application: application, stage: :hiring_manager, position: 3)

    service = InterviewRoundPrep::CompanyPatternsService.new(company: @company, round_type: nil)
    result = service.analyze

    process = result[:typical_process]
    assert process.present?
    assert_equal 1, process[:total_applications_analyzed]
    assert_includes process[:typical_stages], "screening"
  end

  test "calculates success indicators from offer applications" do
    user = create(:user)
    successful_app = create(:interview_application, user: user, company: @company, job_role: @job_role, pipeline_stage: :offer)
    unsuccessful_app = create(:interview_application, user: create(:user), company: @company, job_role: @job_role, pipeline_stage: :applied)

    create(:interview_round, interview_application: successful_app, interview_round_type: @round_type, completed_at: 1.day.ago)
    create(:interview_round, interview_application: unsuccessful_app, interview_round_type: @round_type, completed_at: 2.days.ago)

    service = InterviewRoundPrep::CompanyPatternsService.new(company: @company, round_type: @round_type)
    result = service.analyze

    assert result[:success_indicators].present?
    assert_equal 1, result[:success_indicators][:successful_applications]
    assert_equal 50.0, result[:success_indicators][:success_rate]
  end

  test "calculates average duration for round type" do
    user = create(:user)
    application = create(:interview_application, user: user, company: @company, job_role: @job_role)

    create(:interview_round, interview_application: application, interview_round_type: @round_type, duration_minutes: 45)
    create(:interview_round, interview_application: application, interview_round_type: @round_type, duration_minutes: 60)

    service = InterviewRoundPrep::CompanyPatternsService.new(company: @company, round_type: @round_type)
    result = service.analyze

    # (45+60)/2 = 52.5, rounded - could be 52 or 53 depending on rounding
    assert_includes [ 52, 53 ], result[:average_duration_minutes]
  end

  test "detects remote interview patterns from video links" do
    user = create(:user)
    application = create(:interview_application, user: user, company: @company, job_role: @job_role)

    # Most have video links = remote
    create(:interview_round, interview_application: application, interview_round_type: @round_type, video_link: "https://zoom.us/123")
    create(:interview_round, interview_application: application, interview_round_type: @round_type, video_link: "https://zoom.us/456")
    create(:interview_round, interview_application: application, interview_round_type: @round_type, video_link: nil)

    service = InterviewRoundPrep::CompanyPatternsService.new(company: @company, round_type: @round_type)
    result = service.analyze

    assert_includes result[:interview_style_hints], "Often conducted remotely"
  end
end
