# frozen_string_literal: true

require "test_helper"

class InterviewApplicationTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @company = create(:company)
    @job_role = create(:job_role)
    @application = build(:interview_application, user: @user, company: @company, job_role: @job_role)
  end

  # Validations
  test "valid application" do
    assert @application.valid?
  end

  test "requires user" do
    @application.user = nil
    assert_not @application.valid?
    assert_includes @application.errors[:user], "can't be blank"
  end

  test "requires company" do
    @application.company = nil
    assert_not @application.valid?
    assert_includes @application.errors[:company], "can't be blank"
  end

  test "requires job_role" do
    @application.job_role = nil
    assert_not @application.valid?
    assert_includes @application.errors[:job_role], "can't be blank"
  end

  # Enums
  test "has status enum" do
    assert_respond_to @application, :status
    assert_respond_to @application, :active?
    assert_respond_to @application, :archived?
    assert_respond_to @application, :rejected?
    assert_respond_to @application, :accepted?
  end

  test "has pipeline_stage enum" do
    assert_respond_to @application, :pipeline_stage
    assert_respond_to @application, :applied?
    assert_respond_to @application, :screening?
    assert_respond_to @application, :interviewing?
    assert_respond_to @application, :offer?
    assert_respond_to @application, :closed?
  end

  test "defaults to active status" do
    app = InterviewApplication.create!(user: @user, company: @company, job_role: @job_role)
    assert app.active?
  end

  test "defaults to applied pipeline_stage" do
    app = InterviewApplication.create!(user: @user, company: @company, job_role: @job_role)
    assert app.applied?
  end

  # Associations
  test "belongs to user" do
    assert_respond_to @application, :user
    assert_instance_of User, @application.user
  end

  test "belongs to company" do
    assert_respond_to @application, :company
    assert_instance_of Company, @application.company
  end

  test "belongs to job_role" do
    assert_respond_to @application, :job_role
    assert_instance_of JobRole, @application.job_role
  end

  test "optionally belongs to job_listing" do
    assert_respond_to @application, :job_listing
    @application.job_listing = nil
    assert @application.valid?
  end

  test "has many interview_rounds" do
    app = create(:interview_application, :with_rounds, user: @user, company: @company, job_role: @job_role)
    assert_equal 2, app.interview_rounds.count
  end

  test "has many skill_tags through application_skill_tags" do
    app = create(:interview_application, :with_skills, user: @user, company: @company, job_role: @job_role)
    assert_equal 3, app.skill_tags.count
  end

  test "has one company_feedback" do
    app = create(:interview_application, :with_company_feedback, user: @user, company: @company, job_role: @job_role)
    assert_not_nil app.company_feedback
    assert_instance_of CompanyFeedback, app.company_feedback
  end

  test "destroys dependent interview_rounds" do
    app = create(:interview_application, :with_rounds, user: @user, company: @company, job_role: @job_role)
    round_ids = app.interview_rounds.pluck(:id)
    
    app.destroy
    
    round_ids.each do |id|
      assert_nil InterviewRound.find_by(id: id)
    end
  end

  # Scopes
  test "recent scope orders by created_at desc" do
    app1 = create(:interview_application, user: @user, company: @company, job_role: @job_role, created_at: 2.days.ago)
    app2 = create(:interview_application, user: @user, company: @company, job_role: @job_role, created_at: 1.day.ago)
    
    assert_equal [app2, app1], InterviewApplication.recent.to_a
  end

  test "by_status scope filters by status" do
    active_app = create(:interview_application, :active, user: @user, company: @company, job_role: @job_role)
    archived_app = create(:interview_application, :archived, user: @user, company: @company, job_role: @job_role)
    
    assert_includes InterviewApplication.by_status(:active), active_app
    assert_not_includes InterviewApplication.by_status(:active), archived_app
  end

  test "by_pipeline_stage scope filters by pipeline_stage" do
    applied_app = create(:interview_application, :applied_stage, user: @user, company: @company, job_role: @job_role)
    screening_app = create(:interview_application, :screening_stage, user: @user, company: @company, job_role: @job_role)
    
    assert_includes InterviewApplication.by_pipeline_stage(:applied), applied_app
    assert_not_includes InterviewApplication.by_pipeline_stage(:applied), screening_app
  end

  test "active scope returns only active applications" do
    active_app = create(:interview_application, :active, user: @user, company: @company, job_role: @job_role)
    archived_app = create(:interview_application, :archived, user: @user, company: @company, job_role: @job_role)
    
    assert_includes InterviewApplication.active, active_app
    assert_not_includes InterviewApplication.active, archived_app
  end

  test "archived scope returns only archived applications" do
    active_app = create(:interview_application, :active, user: @user, company: @company, job_role: @job_role)
    archived_app = create(:interview_application, :archived, user: @user, company: @company, job_role: @job_role)
    
    assert_includes InterviewApplication.archived, archived_app
    assert_not_includes InterviewApplication.archived, active_app
  end

  # Helper methods
  test "#card_summary returns formatted summary" do
    app = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    summary = app.card_summary
    
    assert_includes summary, @company.name
    assert_includes summary, @job_role.title
  end

  test "#has_rounds? returns true when rounds exist" do
    app = create(:interview_application, :with_rounds, user: @user, company: @company, job_role: @job_role)
    assert app.has_rounds?
  end

  test "#has_rounds? returns false when no rounds" do
    app = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    assert_not app.has_rounds?
  end

  test "#latest_round returns most recent round" do
    app = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    round1 = create(:interview_round, interview_application: app, position: 1, created_at: 2.days.ago)
    round2 = create(:interview_round, interview_application: app, position: 2, created_at: 1.day.ago)
    
    assert_equal round2, app.latest_round
  end

  test "#completed_rounds_count returns count of completed rounds" do
    app = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    create(:interview_round, :completed, interview_application: app)
    create(:interview_round, :completed, interview_application: app)
    create(:interview_round, :upcoming, interview_application: app)
    
    assert_equal 2, app.completed_rounds_count
  end

  test "#pending_rounds_count returns count of pending rounds" do
    app = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    create(:interview_round, :completed, interview_application: app)
    create(:interview_round, :upcoming, interview_application: app)
    create(:interview_round, :upcoming, interview_application: app)
    
    assert_equal 2, app.pending_rounds_count
  end

  test "#status_badge_color returns correct color for status" do
    app = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    
    app.status = :active
    assert_equal "blue", app.status_badge_color
    
    app.status = :accepted
    assert_equal "green", app.status_badge_color
    
    app.status = :rejected
    assert_equal "red", app.status_badge_color
    
    app.status = :archived
    assert_equal "gray", app.status_badge_color
  end

  test "#pipeline_stage_display returns formatted stage name" do
    app = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    
    app.pipeline_stage = :applied
    assert_equal "Applied", app.pipeline_stage_display
    
    app.pipeline_stage = :screening
    assert_equal "Screening", app.pipeline_stage_display
  end
end

