# frozen_string_literal: true

require "test_helper"

class ScrapingAttemptTest < ActiveSupport::TestCase
  test "should create scraping attempt" do
    job_listing = create(:job_listing)
    attempt = job_listing.scraping_attempts.create!(
      url: job_listing.url,
      domain: "example.com",
      status: :pending
    )

    assert attempt.persisted?
    assert_equal :pending, attempt.status.to_sym
  end

  test "should transition through states" do
    attempt = create(:scraping_attempt)

    assert attempt.pending?
    
    attempt.start_fetch!
    assert attempt.fetching?
    
    attempt.start_extract!
    assert attempt.extracting?
    
    attempt.mark_completed!
    assert attempt.completed?
  end

  test "should handle failure and retry states" do
    attempt = create(:scraping_attempt, status: :fetching)
    
    attempt.mark_failed!
    assert attempt.failed?
    
    attempt.retry_attempt!
    assert attempt.retrying?
  end

  test "should move to dead letter queue" do
    attempt = create(:scraping_attempt, status: :failed)
    
    attempt.send_to_dlq!
    assert attempt.dead_letter?
  end

  test "should mark as manual" do
    attempt = create(:scraping_attempt, status: :dead_letter)
    
    attempt.mark_manual!
    assert attempt.manual?
  end

  test "should return correct status badge color" do
    attempt = create(:scraping_attempt)
    assert_equal "info", attempt.status_badge_color
    
    attempt.mark_completed!
    assert_equal "success", attempt.status_badge_color
  end

  test "should identify when needs review" do
    attempt = create(:scraping_attempt, status: :dead_letter)
    assert attempt.needs_review?
    
    attempt = create(:scraping_attempt, status: :failed, retry_count: 3)
    assert attempt.needs_review?
  end

  test "should calculate success rate for domain" do
    domain = "example.com"
    create(:scraping_attempt, domain: domain, status: :completed)
    create(:scraping_attempt, domain: domain, status: :completed)
    create(:scraping_attempt, domain: domain, status: :failed)
    
    rate = ScrapingAttempt.success_rate_for_domain(domain, 7)
    assert_in_delta 66.7, rate, 0.1
  end
end

