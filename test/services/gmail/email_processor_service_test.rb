# frozen_string_literal: true

require "test_helper"

class Gmail::EmailProcessorServiceTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @connected_account = create(:connected_account, user: @user)
    @company = create(:company, name: "Acme Corp", website: "https://acme.com")
    @job_role = create(:job_role, title: "Software Engineer")
    @application = create(:interview_application,
      user: @user,
      company: @company,
      job_role: @job_role,
      status: :active
    )
  end

  # find_matching_application strategy tests

  test "matches email to application by thread_id (Strategy 1 - highest priority)" do
    # Create an existing email in a thread that's matched to an application
    existing_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      thread_id: "thread_123",
      interview_application: @application,
      from_email: "recruiter@acme.com"
    )

    # Create a new email in the same thread
    new_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      thread_id: "thread_123",
      from_email: "recruiter@acme.com"
    )

    service = Gmail::EmailProcessorService.new(new_email)
    matched_app = service.send(:find_matching_application)

    assert_equal @application, matched_app
  end

  test "matches email by sender consistency (Strategy 2)" do
    # Create an existing email from a sender matched to an application
    existing_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@acme.com",
      interview_application: @application,
      email_date: 1.day.ago
    )

    # Create a new email from the same sender (different thread)
    new_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@acme.com",
      thread_id: "different_thread"
    )

    service = Gmail::EmailProcessorService.new(new_email)
    matched_app = service.send(:find_matching_application)

    assert_equal @application, matched_app
  end

  test "sender consistency only matches active applications" do
    # Mark the application as rejected (inactive)
    @application.update!(status: :rejected)

    # Create an existing email matched to the now-inactive application
    existing_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@acme.com",
      interview_application: @application,
      email_date: 1.day.ago
    )

    # Create a new email from the same sender
    new_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@acme.com"
    )

    service = Gmail::EmailProcessorService.new(new_email)
    matched_app = service.send(:find_matching_application)

    # Should not match inactive application
    assert_nil matched_app
  end

  test "matches email by detected company name (Strategy 3)" do
    new_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@different.com",
      detected_company: "Acme Corp"
    )

    service = Gmail::EmailProcessorService.new(new_email)
    matched_app = service.send(:find_matching_application)

    assert_equal @application, matched_app
  end

  test "thread matching takes priority over sender consistency" do
    # Create a second application for a different company
    other_company = create(:company, name: "Other Corp")
    other_app = create(:interview_application,
      user: @user,
      company: other_company,
      job_role: @job_role,
      status: :active
    )

    # Create an email from recruiter matched to other_app
    create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@example.com",
      interview_application: other_app,
      email_date: 1.day.ago
    )

    # Create an email in a thread matched to @application
    create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      thread_id: "acme_thread",
      from_email: "different@acme.com",
      interview_application: @application
    )

    # New email from the recruiter BUT in the acme thread
    # Thread should take priority
    new_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      thread_id: "acme_thread",
      from_email: "recruiter@example.com"
    )

    service = Gmail::EmailProcessorService.new(new_email)
    matched_app = service.send(:find_matching_application)

    # Should match by thread (Strategy 1), not sender (Strategy 2)
    assert_equal @application, matched_app
  end

  test "sender consistency takes priority over company name matching" do
    # Create a second application for the same company (edge case)
    newer_app = create(:interview_application,
      user: @user,
      company: @company,
      job_role: create(:job_role, title: "Senior Engineer"),
      status: :active,
      created_at: 1.hour.ago
    )

    # Create an email from recruiter matched to the older @application
    create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@acme.com",
      interview_application: @application,
      email_date: 2.days.ago
    )

    # New email from same recruiter, with detected_company matching newer_app's company
    new_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@acme.com",
      detected_company: "Acme Corp"
    )

    service = Gmail::EmailProcessorService.new(new_email)
    matched_app = service.send(:find_matching_application)

    # Should match by sender consistency (Strategy 2), not company name (Strategy 3)
    # which would pick the most recent application
    assert_equal @application, matched_app
  end

  test "returns nil when no matching application found" do
    new_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "unknown@unknown.com"
    )

    service = Gmail::EmailProcessorService.new(new_email)
    matched_app = service.send(:find_matching_application)

    assert_nil matched_app
  end

  test "emails from same sender go to same application even after new application created" do
    # This is the key bug fix scenario:
    # 1. User receives email from recruiter@acme.com, matched to @application
    # 2. User creates a new application at a different company
    # 3. User receives follow-up email from recruiter@acme.com
    # 4. Email should still go to @application, not get lost

    # Step 1: First email matched to application
    first_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@acme.com",
      interview_application: @application,
      email_date: 3.days.ago
    )

    # Step 2: New application created (simulating user starting another process)
    new_company = create(:company, name: "TechCo")
    new_application = create(:interview_application,
      user: @user,
      company: new_company,
      job_role: @job_role,
      status: :active,
      created_at: 1.day.ago
    )

    # Step 3: Follow-up email from same recruiter
    follow_up_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@acme.com",
      email_date: Time.current
    )

    service = Gmail::EmailProcessorService.new(follow_up_email)
    matched_app = service.send(:find_matching_application)

    # Step 4: Should match to original application, not the newer one
    assert_equal @application, matched_app
    assert_not_equal new_application, matched_app
  end

  test "LinkedIn InMail proxy sender auto-matches only by thread (high confidence)" do
    thread_id = "linkedin_thread_123"

    create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "inmail-hit-reply@linkedin.com",
      thread_id: thread_id,
      interview_application: @application,
      email_date: 1.day.ago
    )

    new_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "inmail-hit-reply@linkedin.com",
      thread_id: thread_id
    )

    service = Gmail::EmailProcessorService.new(new_email)
    matched_app = service.send(:find_matching_application)

    assert_equal @application, matched_app
  end

  test "LinkedIn InMail proxy sender does not auto-match by sender consistency across threads" do
    create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "inmail-hit-reply@linkedin.com",
      thread_id: "thread_a",
      interview_application: @application,
      email_date: 1.day.ago
    )

    new_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "inmail-hit-reply@linkedin.com",
      thread_id: "thread_b"
    )

    service = Gmail::EmailProcessorService.new(new_email)
    matched_app = service.send(:find_matching_application)

    assert_nil matched_app
  end

  test "LinkedIn InMail with JOB OFFER subject is classified as recruiter_outreach when content indicates outreach" do
    new_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "inmail-hit-reply@linkedin.com",
      subject: "Principal/Staff Engineer - JOB OFFER - fully remote",
      snippet: "Hi Ravi, I'm reaching out about an opportunity that could be a great fit.",
      body_preview: "Hi Ravi, I'm reaching out about an opportunity that could be a great fit."
    )

    service = Gmail::EmailProcessorService.new(new_email)
    service.send(:classify_email_type)

    assert_equal "recruiter_outreach", new_email.email_type
  end
end
