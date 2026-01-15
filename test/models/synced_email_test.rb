# frozen_string_literal: true

require "test_helper"

class SyncedEmailTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @connected_account = create(:connected_account, user: @user)
    @company = create(:company)
    @job_role = create(:job_role)
    @application = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    @email = build(:synced_email, user: @user, connected_account: @connected_account)
  end

  # Validations
  test "valid email" do
    assert @email.valid?
  end

  test "requires gmail_id" do
    @email.gmail_id = nil
    assert_not @email.valid?
    assert_includes @email.errors[:gmail_id], "can't be blank"
  end

  test "requires from_email" do
    @email.from_email = nil
    assert_not @email.valid?
    assert_includes @email.errors[:from_email], "can't be blank"
  end

  test "gmail_id is unique per user" do
    @email.save!
    duplicate = build(:synced_email, user: @user, connected_account: @connected_account, gmail_id: @email.gmail_id)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:gmail_id], "has already been taken"
  end

  test "validates email_type inclusion" do
    @email.email_type = "invalid_type"
    assert_not @email.valid?
    assert_includes @email.errors[:email_type], "is not included in the list"
  end

  # Email type constants
  test "EMAIL_TYPES includes all expected types" do
    expected_types = %w[
      application_confirmation interview_invite interview_reminder round_feedback
      rejection offer follow_up thank_you scheduling assessment recruiter_outreach other
    ]
    expected_types.each do |type|
      assert_includes SyncedEmail::EMAIL_TYPES, type
    end
  end

  test "INTERVIEW_TYPES includes round_feedback" do
    assert_includes SyncedEmail::INTERVIEW_TYPES, "round_feedback"
  end

  # Status enum
  test "status defaults to pending" do
    email = SyncedEmail.new(
      user: @user,
      connected_account: @connected_account,
      gmail_id: "test",
      from_email: "test@example.com"
    )
    assert email.pending?
  end

  test "status can be set to processed" do
    @email.status = :processed
    assert @email.processed?
  end

  test "status can be set to auto_ignored" do
    @email.status = :auto_ignored
    assert @email.auto_ignored?
  end

  # Associations
  test "belongs to user" do
    assert_respond_to @email, :user
    assert_instance_of User, @email.user
  end

  test "belongs to connected_account" do
    assert_respond_to @email, :connected_account
    assert_instance_of ConnectedAccount, @email.connected_account
  end

  test "belongs to interview_application optionally" do
    assert_respond_to @email, :interview_application
    assert_nil @email.interview_application

    @email.interview_application = @application
    assert_equal @application, @email.interview_application
  end

  test "has one interview_round through source_email" do
    @email.save!
    round = create(:interview_round,
      interview_application: @application,
      source_email_id: @email.id
    )
    assert_equal @email, round.source_email
  end

  # Scopes
  test "unmatched scope returns emails without application" do
    unmatched = create(:synced_email, user: @user, connected_account: @connected_account)
    matched = create(:synced_email, :matched,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    assert_includes SyncedEmail.unmatched, unmatched
    assert_not_includes SyncedEmail.unmatched, matched
  end

  test "matched scope returns emails with application" do
    unmatched = create(:synced_email, user: @user, connected_account: @connected_account)
    matched = create(:synced_email, :matched,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    assert_includes SyncedEmail.matched, matched
    assert_not_includes SyncedEmail.matched, unmatched
  end

  test "by_type scope filters by email type" do
    scheduling = create(:synced_email, :scheduling, user: @user, connected_account: @connected_account)
    rejection = create(:synced_email, :rejection, user: @user, connected_account: @connected_account)

    assert_includes SyncedEmail.by_type("scheduling"), scheduling
    assert_not_includes SyncedEmail.by_type("scheduling"), rejection
  end

  test "visible scope excludes ignored and auto_ignored" do
    visible = create(:synced_email, user: @user, connected_account: @connected_account)
    ignored = create(:synced_email, :ignored, user: @user, connected_account: @connected_account)
    auto_ignored = create(:synced_email, :auto_ignored, user: @user, connected_account: @connected_account)

    assert_includes SyncedEmail.visible, visible
    assert_not_includes SyncedEmail.visible, ignored
    assert_not_includes SyncedEmail.visible, auto_ignored
  end

  # Helper methods
  test "#matched? returns true when application present" do
    @email.interview_application = @application
    assert @email.matched?
  end

  test "#matched? returns false when application nil" do
    @email.interview_application = nil
    assert_not @email.matched?
  end

  test "interview_related scope includes interview types" do
    SyncedEmail::INTERVIEW_TYPES.each do |type|
      @email.email_type = type
      @email.save!
      assert_includes SyncedEmail.interview_related, @email, "Expected #{type} to be in interview_related scope"
    end
  end

  test "interview_related scope includes matched emails" do
    @email.email_type = "other"
    @email.interview_application = @application
    @email.save!
    assert_includes SyncedEmail.interview_related, @email
  end

  # Extraction fields
  test "has extraction status fields" do
    assert_respond_to @email, :extraction_status
    assert_respond_to @email, :extraction_confidence
    assert_respond_to @email, :extracted_at
    assert_respond_to @email, :extracted_data
  end

  test "extraction_status defaults to pending" do
    email = SyncedEmail.new(
      user: @user,
      connected_account: @connected_account,
      gmail_id: "test",
      from_email: "test@example.com"
    )
    assert_equal "pending", email.extraction_status
  end

  test "can set extracted data" do
    @email.extracted_data = {
      "signal_company_name" => "Test Corp",
      "signal_job_title" => "Engineer"
    }
    @email.save!

    @email.reload
    assert_equal "Test Corp", @email.extracted_data["signal_company_name"]
    assert_equal "Engineer", @email.extracted_data["signal_job_title"]
  end

  # Store accessors for extracted_data
  test "has signal store accessors" do
    @email.signal_company_name = "Test Corp"
    @email.signal_recruiter_name = "Jane Doe"
    @email.signal_job_title = "Software Engineer"

    assert_equal "Test Corp", @email.signal_company_name
    assert_equal "Jane Doe", @email.signal_recruiter_name
    assert_equal "Software Engineer", @email.signal_job_title
  end

  # Normalizations
  test "normalizes from_email to lowercase" do
    @email.from_email = " TEST@EXAMPLE.COM "
    @email.save!
    assert_equal "test@example.com", @email.from_email
  end
end
