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

  # safe_html_body tests
  test "safe_html_body returns nil when body_html is blank" do
    @email.body_html = nil
    assert_nil @email.safe_html_body

    @email.body_html = ""
    assert_nil @email.safe_html_body
  end

  test "safe_html_body preserves safe inline styles" do
    @email.body_html = '<div style="color: #333; text-align: center; padding: 10px;">Content</div>'
    result = @email.safe_html_body

    assert_includes result, "color: #333"
    assert_includes result, "text-align: center"
    assert_includes result, "padding: 10px"
  end

  test "safe_html_body preserves background colors" do
    @email.body_html = '<div style="background-color: #0077B5; background: white;">LinkedIn</div>'
    result = @email.safe_html_body

    assert_includes result, "background-color: #0077B5"
    assert_includes result, "background: white"
  end

  test "safe_html_body preserves font styles" do
    @email.body_html = '<span style="font-weight: bold; font-size: 16px; font-family: Arial;">Text</span>'
    result = @email.safe_html_body

    assert_includes result, "font-weight: bold"
    assert_includes result, "font-size: 16px"
    assert_includes result, "font-family: Arial"
  end

  test "safe_html_body preserves border styles" do
    @email.body_html = '<div style="border: 1px solid #ccc; border-radius: 5px;">Box</div>'
    result = @email.safe_html_body

    assert_includes result, "border: 1px solid #ccc"
    assert_includes result, "border-radius: 5px"
  end

  test "safe_html_body removes javascript in style values" do
    @email.body_html = '<div style="background: url(javascript:alert(1));">Malicious</div>'
    result = @email.safe_html_body

    assert_not_includes result, "javascript:"
  end

  test "safe_html_body removes expression() in style values" do
    @email.body_html = '<div style="width: expression(alert(1));">Malicious</div>'
    result = @email.safe_html_body

    assert_not_includes result, "expression("
  end

  test "safe_html_body removes vbscript in style values" do
    @email.body_html = '<div style="background: url(vbscript:alert(1));">Malicious</div>'
    result = @email.safe_html_body

    assert_not_includes result, "vbscript:"
  end

  test "safe_html_body removes unsafe url() but keeps safe ones" do
    @email.body_html = '<div style="background: url(https://example.com/image.png);">Safe URL</div>'
    result = @email.safe_html_body

    assert_includes result, "url(https://example.com/image.png)"
  end

  test "safe_html_body removes position and other dangerous properties" do
    @email.body_html = '<div style="position: fixed; z-index: 9999; top: 0;">Overlay</div>'
    result = @email.safe_html_body

    # Position and z-index are not in the safe list
    assert_not_includes result, "position:"
    assert_not_includes result, "z-index:"
  end

  test "safe_html_body removes style attribute when no safe properties remain" do
    @email.body_html = '<div style="position: fixed;">Only unsafe</div>'
    result = @email.safe_html_body

    # The style attribute should be removed entirely
    assert_not_includes result, 'style="'
  end

  test "safe_html_body sanitizes complex email with multiple styles" do
    @email.body_html = <<~HTML
      <div style="max-width: 600px; margin: 0 auto; background-color: #f4f4f4;">
        <table style="width: 100%; border-collapse: collapse;">
          <tr>
            <td style="padding: 20px; text-align: center; background-color: #0077B5;">
              <span style="color: white; font-size: 24px; font-weight: bold;">LinkedIn</span>
            </td>
          </tr>
          <tr>
            <td style="padding: 30px; background: white;">
              <p style="color: #333; line-height: 1.6;">Hello!</p>
            </td>
          </tr>
        </table>
      </div>
    HTML

    result = @email.safe_html_body

    # Should preserve safe styles
    assert_includes result, "max-width: 600px"
    assert_includes result, "background-color: #0077B5"
    assert_includes result, "color: white"
    assert_includes result, "font-size: 24px"
    assert_includes result, "padding: 20px"
    assert_includes result, "text-align: center"
  end

  test "SAFE_STYLE_PROPERTIES constant includes expected properties" do
    expected = %w[
      text-align color background-color background
      font-weight font-size padding margin border border-radius
      width max-width height display
    ]

    expected.each do |prop|
      assert_includes SyncedEmail::SAFE_STYLE_PROPERTIES, prop,
        "Expected SAFE_STYLE_PROPERTIES to include #{prop}"
    end
  end
end
