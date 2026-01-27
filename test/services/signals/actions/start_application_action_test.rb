# frozen_string_literal: true

require "test_helper"

class Signals::Actions::StartApplicationActionTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @connected_account = create(:connected_account, user: @user)
    @email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      from_email: "recruiter@techcorp.com",
      signal_company_name: "TechCorp",
      signal_job_title: "Software Engineer"
    )
  end

  # Basic execution tests

  test "creates application with company and job role" do
    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    result = action.execute

    assert result[:success]
    assert_not_nil result[:application]
    assert_not_nil result[:company]
    # Company name gets titleized: "TechCorp" -> "Tech Corp"
    assert_equal "Tech Corp", result[:company].name
  end

  test "returns failure when company name is missing" do
    @email.update!(signal_company_name: nil)
    @email.reload

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    result = action.execute

    assert_not result[:success]
    assert_includes result[:error], "No company name"
  end

  # Job URL detection tests

  test "detected_job_url returns signal_job_url when present" do
    @email.update!(signal_job_url: "https://lever.co/techcorp/job123")

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    assert_equal "https://lever.co/techcorp/job123", detected
  end

  test "detected_job_url finds job URL from action_links by label" do
    @email.update!(
      signal_job_url: nil,
      signal_action_links: [
        { "url" => "https://calendly.com/recruiter", "action_label" => "Schedule Call", "priority" => 1 },
        { "url" => "https://techcorp.com/jobs/123", "action_label" => "View Job Posting", "priority" => 3 }
      ]
    )

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    assert_equal "https://techcorp.com/jobs/123", detected
  end

  test "detected_job_url finds job URL from action_links by URL pattern" do
    @email.update!(
      signal_job_url: nil,
      signal_action_links: [
        { "url" => "https://calendly.com/recruiter", "action_label" => "Schedule", "priority" => 1 },
        { "url" => "https://jobs.lever.co/techcorp/abc123", "action_label" => "Learn More", "priority" => 2 }
      ]
    )

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    assert_equal "https://jobs.lever.co/techcorp/abc123", detected
  end

  test "detected_job_url recognizes common ATS patterns" do
    ats_patterns = [
      "https://jobs.lever.co/company/job",
      "https://boards.greenhouse.io/company/jobs/123",
      "https://company.wd5.myworkdaysite.com/careers/job",
      "https://company.ashbyhq.com/jobs/engineer",
      "https://company.careers.smartrecruiters.com/job"
    ]

    ats_patterns.each do |url|
      @email.update!(
        signal_job_url: nil,
        signal_action_links: [
          { "url" => url, "action_label" => "Details", "priority" => 2 }
        ]
      )

      action = Signals::Actions::StartApplicationAction.new(@email, @user)
      detected = action.send(:detected_job_url)

      assert_equal url, detected, "Failed to detect ATS URL: #{url}"
    end
  end

  test "detected_job_url returns nil when no job URL found" do
    @email.update!(
      signal_job_url: nil,
      signal_action_links: [
        { "url" => "https://calendly.com/recruiter", "action_label" => "Schedule", "priority" => 1 }
      ]
    )

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    assert_nil detected
  end

  # Job listing creation tests

  test "creates job listing when job URL is present" do
    @email.update!(signal_job_url: "https://lever.co/techcorp/job123")

    action = Signals::Actions::StartApplicationAction.new(@email, @user)

    assert_difference "JobListing.count", 1 do
      result = action.execute
      assert result[:success]
      assert_not_nil result[:job_listing]
      assert_equal "https://lever.co/techcorp/job123", result[:job_listing].url
    end
  end

  test "associates job listing with application" do
    @email.update!(signal_job_url: "https://lever.co/techcorp/job123")

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    result = action.execute

    assert result[:success]
    assert_equal result[:job_listing], result[:application].job_listing
  end

  test "reuses existing job listing when URL matches" do
    company = create(:company, name: "TechCorp")
    job_role = create(:job_role, title: "Software Engineer")
    existing_listing = create(:job_listing,
      url: "https://lever.co/techcorp/job123",
      company: company,
      job_role: job_role
    )

    @email.update!(signal_job_url: "https://lever.co/techcorp/job123")

    action = Signals::Actions::StartApplicationAction.new(@email, @user)

    assert_no_difference "JobListing.count" do
      result = action.execute
      assert result[:success]
      assert_equal existing_listing, result[:job_listing]
    end
  end

  test "normalizes job URL by removing tracking parameters" do
    @email.update!(signal_job_url: "https://lever.co/techcorp/job123?utm_source=linkedin&utm_medium=social&ref=abc")

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    result = action.execute

    assert result[:success]
    # URL should have tracking params removed
    assert_equal "https://lever.co/techcorp/job123", result[:job_listing].url
  end

  test "does not create job listing when no URL present" do
    @email.update!(signal_job_url: nil, signal_action_links: nil)

    action = Signals::Actions::StartApplicationAction.new(@email, @user)

    assert_no_difference "JobListing.count" do
      result = action.execute
      assert result[:success]
      assert_nil result[:job_listing]
    end
  end

  # Scraping trigger tests

  test "enqueues scraping job for new job listing" do
    @email.update!(signal_job_url: "https://lever.co/techcorp/job123")

    action = Signals::Actions::StartApplicationAction.new(@email, @user)

    assert_enqueued_with(job: ScrapeJobListingJob) do
      action.execute
    end
  end

  test "does not enqueue scraping job for existing job listing" do
    company = create(:company, name: "TechCorp")
    job_role = create(:job_role, title: "Software Engineer")
    existing_listing = create(:job_listing,
      url: "https://lever.co/techcorp/job123",
      company: company,
      job_role: job_role,
      scraped_data: { "status" => "completed" }
    )

    @email.update!(signal_job_url: "https://lever.co/techcorp/job123")

    action = Signals::Actions::StartApplicationAction.new(@email, @user)

    assert_no_enqueued_jobs(only: ScrapeJobListingJob) do
      action.execute
    end
  end

  test "does not enqueue scraping when no job URL" do
    @email.update!(signal_job_url: nil, signal_action_links: nil)

    action = Signals::Actions::StartApplicationAction.new(@email, @user)

    assert_no_enqueued_jobs(only: ScrapeJobListingJob) do
      action.execute
    end
  end

  # Job listing detection label patterns

  test "detects job URL by apply label" do
    @email.update!(
      signal_job_url: nil,
      signal_action_links: [
        { "url" => "https://company.com/apply", "action_label" => "Apply Now" }
      ]
    )

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    assert_equal "https://company.com/apply", detected
  end

  test "detects job URL by see position label" do
    @email.update!(
      signal_job_url: nil,
      signal_action_links: [
        { "url" => "https://company.com/position/123", "action_label" => "See Full Position" }
      ]
    )

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    assert_equal "https://company.com/position/123", detected
  end

  test "detects job URL by job details label" do
    @email.update!(
      signal_job_url: nil,
      signal_action_links: [
        { "url" => "https://company.com/role/456", "action_label" => "View Job Details" }
      ]
    )

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    assert_equal "https://company.com/role/456", detected
  end

  # Edge cases

  test "handles empty action_links array" do
    @email.update!(signal_job_url: nil, signal_action_links: [])

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    assert_nil detected
  end

  test "handles nil action_links" do
    @email.update!(signal_job_url: nil, signal_action_links: nil)

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    assert_nil detected
  end

  test "handles malformed action_links entries" do
    @email.update!(
      signal_job_url: nil,
      signal_action_links: [
        "not a hash",
        { "no_url_key" => true },
        { "url" => "https://lever.co/job", "action_label" => "View Job" }
      ]
    )

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    # Should skip malformed entries and find the valid one
    assert_equal "https://lever.co/job", detected
  end

  test "prioritizes signal_job_url over action_links" do
    @email.update!(
      signal_job_url: "https://direct-job-url.com/job",
      signal_action_links: [
        { "url" => "https://action-link-job.com/job", "action_label" => "View Job" }
      ]
    )

    action = Signals::Actions::StartApplicationAction.new(@email, @user)
    detected = action.send(:detected_job_url)

    assert_equal "https://direct-job-url.com/job", detected
  end
end
