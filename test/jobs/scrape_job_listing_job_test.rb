# frozen_string_literal: true

require "test_helper"

class ScrapeJobListingJobTest < ActiveJob::TestCase
  test "should not run without url" do
    job_listing = create(:job_listing, url: nil)
    
    assert_nothing_raised do
      ScrapeJobListingJob.perform_now(job_listing)
    end
  end

  test "should create scraping attempt" do
    job_listing = create(:job_listing, url: "https://example.com/jobs/123")
    
    # Mock the orchestrator to avoid actual extraction
    Scraping::OrchestratorService.any_instance.stubs(:call).returns(true)
    
    assert_difference "ScrapingAttempt.count", 1 do
      ScrapeJobListingJob.perform_now(job_listing)
    end
  end

  test "should log successful extraction" do
    job_listing = create(:job_listing, url: "https://example.com/jobs/123")
    
    Scraping::OrchestratorService.any_instance.stubs(:call).returns(true)
    
    assert_nothing_raised do
      ScrapeJobListingJob.perform_now(job_listing)
    end
  end

  test "should handle extraction failure" do
    job_listing = create(:job_listing, url: "https://example.com/jobs/123")
    
    Scraping::OrchestratorService.any_instance.stubs(:call).returns(false)
    
    assert_raises StandardError do
      ScrapeJobListingJob.perform_now(job_listing)
    end
  end
end

