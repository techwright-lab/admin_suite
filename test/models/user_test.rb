# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = build(:user)
  end

  test "valid user" do
    assert @user.valid?
  end

  test "requires email_address" do
    @user.email_address = nil
    assert_not @user.valid?
    assert_includes @user.errors[:email_address], "can't be blank"
  end

  test "requires unique email_address" do
    create(:user, email_address: "test@example.com")
    @user.email_address = "test@example.com"
    assert_not @user.valid?
    assert_includes @user.errors[:email_address], "has already been taken"
  end

  test "normalizes email_address" do
    @user.email_address = "  TEST@EXAMPLE.COM  "
    @user.save!
    assert_equal "test@example.com", @user.email_address
  end

  test "has secure password" do
    assert @user.authenticate("password")
    assert_not @user.authenticate("wrong_password")
  end

  test "creates default preference after creation" do
    user = create(:user)
    assert_not_nil user.preference
    assert user.preference.persisted?
  end

  test "has many interview_applications" do
    user = create(:user, :with_applications)
    assert_equal 3, user.interview_applications.count
  end

  test "destroys dependent interview_applications" do
    user = create(:user, :with_applications)
    application_ids = user.interview_applications.pluck(:id)
    
    user.destroy
    
    application_ids.each do |id|
      assert_nil InterviewApplication.find_by(id: id)
    end
  end

  test "#display_name returns name when present" do
    @user.name = "John Doe"
    assert_equal "John Doe", @user.display_name
  end

  test "#display_name returns email prefix when name blank" do
    @user.name = nil
    @user.email_address = "john.doe@example.com"
    assert_equal "john.doe", @user.display_name
  end

  test "#total_applications_count" do
    user = create(:user, :with_applications)
    assert_equal 3, user.total_applications_count
  end

  test "#applications_by_status groups applications correctly" do
    user = create(:user)
    company = create(:company)
    job_role = create(:job_role)
    
    create(:interview_application, user: user, company: company, job_role: job_role, status: :active)
    create(:interview_application, user: user, company: company, job_role: job_role, status: :archived)
    create(:interview_application, user: user, company: company, job_role: job_role, status: :rejected)
    
    grouped = user.applications_by_status
    assert_equal 1, grouped[:active].count
    assert_equal 1, grouped[:archived].count
    assert_equal 1, grouped[:rejected].count
  end

  test "has optional current_job_role" do
    user = create(:user, :with_current_role)
    assert_not_nil user.current_job_role
    assert_instance_of JobRole, user.current_job_role
  end

  test "has optional current_company" do
    user = create(:user, :with_current_company)
    assert_not_nil user.current_company
    assert_instance_of Company, user.current_company
  end

  test "has many target_job_roles" do
    user = create(:user, :with_targets)
    assert_equal 2, user.target_job_roles.count
    assert user.target_job_roles.all? { |jr| jr.is_a?(JobRole) }
  end

  test "has many target_companies" do
    user = create(:user, :with_targets)
    assert_equal 2, user.target_companies.count
    assert user.target_companies.all? { |c| c.is_a?(Company) }
  end

  test "#current_role_name returns job role title" do
    user = create(:user, :with_current_role)
    assert_equal user.current_job_role.title, user.current_role_name
  end

  test "#current_role_name returns nil when no job role" do
    user = create(:user)
    assert_nil user.current_role_name
  end

  test "#current_company_name returns company name" do
    user = create(:user, :with_current_company)
    assert_equal user.current_company.name, user.current_company_name
  end

  test "#current_company_name returns nil when no company" do
    user = create(:user)
    assert_nil user.current_company_name
  end

  test "#email_verified? returns true when email_verified_at is set" do
    user = create(:user, email_verified_at: Time.current)
    assert user.email_verified?
  end

  test "#email_verified? returns false when email_verified_at is nil" do
    user = create(:user, :unverified)
    assert_not user.email_verified?
  end

  test "#verify_email! sets email_verified_at" do
    user = create(:user, :unverified)
    
    assert_changes -> { user.reload.email_verified_at }, from: nil do
      user.verify_email!
    end
  end

  test "#oauth_user? returns true when oauth_provider is present" do
    user = create(:user, :oauth_user)
    assert user.oauth_user?
  end

  test "#oauth_user? returns false when oauth_provider is nil" do
    user = create(:user)
    assert_not user.oauth_user?
  end

  test "generates email verification token" do
    user = create(:user)
    token = user.generate_token_for(:email_verification)
    
    assert_not_nil token
    assert_equal user, User.find_by_token_for(:email_verification, token)
  end
end
