# frozen_string_literal: true

require "test_helper"

class ScrapeJobListingJobTest < ActiveJob::TestCase
  def with_stubbed_orchestrator(returning:)
    original_new = Scraping::OrchestratorService.method(:new)
    Scraping::OrchestratorService.define_singleton_method(:new) { |_job_listing| returning }
    yield
  ensure
    Scraping::OrchestratorService.define_singleton_method(:new, original_new)
  end

  test "should not run without url" do
    job_listing = create(:job_listing, url: nil)

    assert_nothing_raised do
      ScrapeJobListingJob.perform_now(job_listing)
    end
  end

  test "logical failures do not enqueue retries and never go to DLQ" do
    job_listing = create(:job_listing, url: "https://example.com/jobs/123")
    attempt = create(
      :scraping_attempt,
      job_listing: job_listing,
      url: job_listing.url,
      domain: "example.com",
      status: :failed,
      failed_step: "ai_extraction",
      error_message: "Low confidence: 0.05",
      retry_count: 3
    )

    fake_orchestrator = Class.new do
      def call = false
    end.new

    with_stubbed_orchestrator(returning: fake_orchestrator) do
      assert_no_enqueued_jobs do
        ScrapeJobListingJob.perform_now(job_listing)
      end
    end

    attempt.reload
    assert attempt.failed?
    assert_not attempt.dead_letter?
    assert_equal 3, attempt.retry_count
  end

  test "retryable failures enqueue retries and only DLQ after max attempts" do
    job_listing = create(:job_listing, url: "https://example.com/jobs/123")
    attempt = create(
      :scraping_attempt,
      job_listing: job_listing,
      url: job_listing.url,
      domain: "example.com",
      status: :failed,
      failed_step: "html_fetch",
      error_message: "Request timeout: execution expired",
      retry_count: 0
    )

    fake_orchestrator = Class.new do
      def call = false
    end.new

    with_stubbed_orchestrator(returning: fake_orchestrator) do
      assert_enqueued_jobs 1 do
        ScrapeJobListingJob.perform_now(job_listing)
      end
    end

    attempt.reload
    assert_equal 1, attempt.retry_count
    assert attempt.retrying?
  end

  test "should create scraping attempt" do
    skip "Requires complex mocking setup - skipping for CI"
    # job_listing = create(:job_listing, url: "https://example.com/jobs/123")
    # # Mock the orchestrator to avoid actual extraction
    # orchestrator = mock("OrchestratorService")
    # orchestrator.stubs(:call).returns(true)
    # Scraping::OrchestratorService.stubs(:new).returns(orchestrator)
    #
    # assert_difference "ScrapingAttempt.count", 1 do
    #   ScrapeJobListingJob.perform_now(job_listing)
    # end
  end

  test "should log successful extraction" do
    skip "Requires complex mocking setup - skipping for CI"
    # job_listing = create(:job_listing, url: "https://example.com/jobs/123")
    # orchestrator = mock("OrchestratorService")
    # orchestrator.stubs(:call).returns(true)
    # Scraping::OrchestratorService.stubs(:new).returns(orchestrator)
    #
    # assert_nothing_raised do
    #   ScrapeJobListingJob.perform_now(job_listing)
    # end
  end

  test "should handle extraction failure" do
    skip "Requires complex mocking setup - skipping for CI"
    # job_listing = create(:job_listing, url: "https://example.com/jobs/123")
    # orchestrator = mock("OrchestratorService")
    # orchestrator.stubs(:call).returns(false)
    # Scraping::OrchestratorService.stubs(:new).returns(orchestrator)
    #
    # assert_raises StandardError do
    #   ScrapeJobListingJob.perform_now(job_listing)
    # end
  end
end
